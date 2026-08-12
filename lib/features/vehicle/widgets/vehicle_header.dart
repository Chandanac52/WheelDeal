import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers/favorites_provider.dart';
import 'chat_start_helper.dart';

/// Back + favorite circular buttons overlaid on top of the image gallery.
class VehicleHeaderOverlay extends ConsumerWidget {
  final String vehicleId;

  const VehicleHeaderOverlay({super.key, required this.vehicleId});

  // FIX: same root cause as FeaturedCarCard's heart — this called
  // favoritesProvider.notifier.toggle() directly with no sign-in check.
  // favorites_provider.dart's toggle() is optimistic: it fills the heart
  // immediately, then calls the API, and SILENTLY REVERTS it in the catch
  // block on any failure — including the 401 a signed-out tap always gets.
  // That optimistic-fill-then-silent-revert is exactly what looked like a
  // "flicker." Gating here the same way chat/call/callback/favorite
  // already are (via the one shared ensureSignedIn()) means toggle() is
  // never even called for a signed-out tap, so there's nothing to revert.
  Future<void> _handleFavoriteTap(BuildContext context, WidgetRef ref) async {
    final signedIn = await ensureSignedIn(
      context,
      ref,
      message: 'Create a free account or sign in to save vehicles to your favorites.',
    );
    if (!signedIn) return;
    ref.read(favoritesProvider.notifier).toggle(vehicleId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(vehicleId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          _CircleButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            iconColor: isFavorite ? Colors.red : Colors.black87,
            onTap: () => _handleFavoriteTap(context, ref),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}