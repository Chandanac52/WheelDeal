import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/providers/auth_provider.dart';
import '../../../services/repositories/vehicle_service.dart';
import '../../chat/chat_detail_screen.dart' show ChatOpenArgs;

Future<void> launchTel(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(scheme: 'tel', path: cleaned);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

/// The single sign-in gate for every action that requires an account:
/// Call, In-App Chat, WhatsApp, and Request Callback all funnel through
/// this now, instead of each deciding independently whether to check (which
/// is exactly how Call/WhatsApp/Callback ended up working anonymously while
/// only Chat was actually gated, and how Callback's silent 401 got papered
/// over with a misleading "(demo mode)" message instead of a real prompt).
///
/// Returns true if the person is already signed in — the caller should
/// proceed immediately. Returns false if they were signed out: a dialog
/// was shown, and either they dismissed it or chose to sign in (which
/// navigates to /login). Either way the ORIGINAL action does not proceed —
/// there's nothing to resume automatically once they're back, so callers
/// should simply stop, not retry.
Future<bool> ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  String message = 'Create a free account or sign in to contact the seller.',
}) async {
  final auth = ref.read(authProvider);
  if (auth.isAuthenticated) return true;

  final shouldSignIn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign in required'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sign In'),
        ),
      ],
    ),
  );

  if (shouldSignIn == true && context.mounted) context.push('/login');
  return false;
}

/// Starts (or opens the existing) chat with this vehicle's seller.
///
/// This is the ONLY place this logic should live — vehicle_details_screen.dart
/// and contact_button.dart both call this directly now instead of each
/// keeping their own local copy. They used to: each had its own duplicate
/// implementation, and because a local top-level declaration silently
/// shadows an import of the same name in Dart, both files' imports of this
/// helper were dead code — neither screen was actually getting the sign-in
/// check below, so a signed-out tap surfaced a raw
/// "Could not start chat: Authentication required" SnackBar instead of a
/// proper prompt. Keeping exactly one implementation is what makes that
/// impossible to regress back into.
Future<void> openChatWithSeller(BuildContext context, WidgetRef ref, VehicleModel vehicle) async {
  final signedIn = await ensureSignedIn(
    context,
    ref,
    message: 'Create a free account or sign in to message sellers directly in the app.',
  );
  if (!signedIn) return;
  if (!context.mounted) return;

  if (!ApiConstants.useMockData && vehicle.sellerId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("This seller hasn't set up in-app chat yet. Try calling them instead."),
        action: SnackBarAction(label: 'Call', onPressed: () => launchTel(vehicle.sellerPhone)),
      ),
    );
    return;
  }

  try {
    final result = await VehicleService.instance.createChat(
      vehicle.sellerId ?? '',
      vehicleId: vehicle.id,
    );
    if (context.mounted) {
      // Pre-fills the buyer's own message box with a suggested opener
      // naming this specific vehicle — they can read it, edit it, or clear
      // it entirely, but it is NEVER sent on their behalf. Nothing reaches
      // the seller until the buyer themselves taps send in the chat screen.
      //
      // Only shown for a genuinely first-ever chat with this seller
      // (result.isNew) — reusing an existing thread never overwrites
      // whatever the buyer might type, or repeats an intro already sent,
      // whether that earlier chat was about this same vehicle or another.
      context.push(
        '/chat/${result.chatId}',
        extra: ChatOpenArgs(
          otherUserName: vehicle.sellerName,
          draftMessage: result.isNew
              ? "Hi! I'd like to know more about your ${vehicle.name}. Is it still available?"
              : null,
        ),
      );
    }
  } catch (e) {
    // A genuine failure at this point (network blip, server error) — not
    // the sign-in case, that's already handled above. Keep this generic
    // rather than surfacing the raw exception text.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong starting the chat. Please try again.')),
      );
    }
  }
}