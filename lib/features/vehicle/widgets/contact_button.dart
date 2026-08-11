import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/repositories/vehicle_service.dart';
import 'chat_start_helper.dart';

class ContactButton extends ConsumerWidget {
  final VehicleModel vehicle;

  const ContactButton({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ElevatedButton(
          onPressed: () async {
            // Single gate for the whole sheet: Call, In-App Chat, WhatsApp,
            // and Request Callback all require an account now, so it's the
            // "Contact Seller" tap itself that's gated — a signed-out
            // person never even sees the 4 options, rather than tapping in
            // and having some of them silently fail or work anonymously
            // while others don't.
            final signedIn = await ensureSignedIn(context, ref);
            if (signedIn && context.mounted) showContactSheet(context, ref, vehicle);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text("Contact Seller"),
        ),
      ),
    );
  }
}

/// Launches WhatsApp with the given phone number. Kept local — this is the
/// only place in the app that opens WhatsApp specifically, so it doesn't
/// belong in the shared chat_start_helper.dart alongside the in-app chat
/// and phone-call helpers.
Future<void> _launchWhatsApp(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.parse('https://wa.me/$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// By the time this sheet is ever shown, ContactButton has already gated
/// entry on ensureSignedIn() above — so every option below can now assume
/// the person is signed in and just do its job, no individual auth checks
/// scattered across four different onTap handlers.
void showContactSheet(BuildContext context, WidgetRef ref, VehicleModel vehicle) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    // FIX: this callback's parameter used to also be named `context`,
    // silently shadowing the outer one above. Every onTap below did
    // `Navigator.pop(context)` then `await ...(context, ...)` using that
    // SAME shadowed, sheet-scoped context — which starts getting disposed
    // the instant it's popped. Any action slow enough to outlast the
    // sheet's closing animation (a genuinely new chat takes one extra DB
    // write vs. reusing an existing thread, for example) would find that
    // context no longer mounted, and any `context.mounted` guard would
    // then silently swallow the navigation/snackbar — looking exactly like
    // "nothing happened" with no error. Renamed to sheetContext, used only
    // for the pop itself; every action after the pop now uses the outer,
    // durable `context`, which belongs to the screen underneath and stays
    // mounted regardless of the sheet's own lifecycle.
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Contact ${vehicle.sellerName}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.sellerPhone,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _ContactOption(
                  icon: Icons.call,
                  iconBackground: AppColors.successLight,
                  iconColor: AppColors.success,
                  title: "Call Seller",
                  subtitle: "Direct call to seller",
                  onTap: () {
                    Navigator.pop(sheetContext);
                    launchTel(vehicle.sellerPhone);
                  },
                ),
                const SizedBox(height: 12),
                _ContactOption(
                  icon: Icons.chat_bubble_outline,
                  iconBackground: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  title: "In-App Chat",
                  subtitle: "Send a message",
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await openChatWithSeller(context, ref, vehicle);
                  },
                ),
                const SizedBox(height: 12),
                _ContactOption(
                  icon: Icons.chat,
                  iconBackground: const Color(0xFFE1F5E4),
                  iconColor: const Color(0xFF25D366),
                  title: "WhatsApp",
                  subtitle: "Chat on WhatsApp",
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchWhatsApp(vehicle.sellerPhone);
                  },
                ),
                const SizedBox(height: 12),
                _ContactOption(
                  icon: Icons.phone_callback_outlined,
                  iconBackground: const Color(0xFFE9E3F7),
                  iconColor: const Color(0xFF7C5FCC),
                  title: "Request Callback",
                  subtitle: "Seller will call you back",
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await VehicleService.instance.requestCallback(vehicle.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Callback request sent!')),
                        );
                      }
                    } catch (e) {
                      // FIX: this used to catch _every_ failure — including
                      // a signed-out 401 — and paper over it with
                      // "Callback request noted (demo mode)", which just
                      // hid the fact that nothing was actually sent. Now
                      // that ContactButton gates sign-in before this sheet
                      // can even open, a failure reaching here is a real
                      // error (network, server), so it should say so.
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Could not send callback request. Please try again.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}