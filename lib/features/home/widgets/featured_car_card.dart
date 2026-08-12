import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wheeldeal/features/vehicle/widgets/chat_start_helper.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_image.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/providers/favorites_provider.dart';


class FeaturedCarCard extends ConsumerWidget {
  final VehicleModel vehicle;

  const FeaturedCarCard({super.key, required this.vehicle});

  // FIX: this used to call favoritesProvider.notifier.toggle() directly,
  // with no sign-in check at all — the ONLY write action in this app that
  // didn't funnel through ensureSignedIn() (chat, calling the seller, and
  // requesting a callback all already do). A favorite is stored per-userId
  // server-side (Favorite has a userId column and a unique(userId,
  // vehicleId) constraint) — it has no meaning without an identity behind
  // it, so tapping it while signed out isn't a smaller version of the
  // action, it's not a valid request at all: the backend 401s, and the
  // optimistic fill this button did locally had to be reverted right
  // after — that reversal was the "flicker." Gating here the same way the
  // other three actions already are is what stops both problems (a
  // confusing signed-out favorite AND the flicker) at once.
  Future<void> _handleFavoriteTap(BuildContext context, WidgetRef ref) async {
    final signedIn = await ensureSignedIn(
      context,
      ref,
      message: 'Create a free account or sign in to save vehicles to your favorites.',
    );
    if (!signedIn) return;
    ref.read(favoritesProvider.notifier).toggle(vehicle.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(vehicle.id);

    return GestureDetector(
      onTap: () => context.push('/vehicle/${vehicle.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.35,
                  child: AppImage(
                    source: vehicle.images.first,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                if (vehicle.isFeatured)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Badge(
                      text: "Featured",
                      background: AppColors.featuredBadge,
                    ),
                  ),
                if (vehicle.discountPercent != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Badge(
                      text: "${vehicle.discountPercent}% off",
                      background: AppColors.discountBadge,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${vehicle.year} • ${vehicle.kmDriven}",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.price,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (vehicle.originalPrice != null)
                              Text(
                                vehicle.originalPrice!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _handleFavoriteTap(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? AppColors.primaryLight
                                : AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 18,
                            color: isFavorite
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color background;

  const _Badge({required this.text, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}