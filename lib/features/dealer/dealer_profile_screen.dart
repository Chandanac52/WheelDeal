import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/providers/auth_provider.dart';
import '../../services/providers/vehicle_providers.dart';
import '../../services/repositories/vehicle_service.dart';
import '../../widgets/app_image.dart';
import '../home/widgets/featured_car_card.dart';

class DealerProfileScreen extends ConsumerWidget {
  final String dealerId;

  const DealerProfileScreen({super.key, required this.dealerId});

  Future<void> _openRatingSheet(BuildContext context, WidgetRef ref) async {
    // Signing in is required to review — same "who is this rating even
    // from" reasoning as everywhere else a person's identity backs a
    // write (chat, favorites, callback requests).
    if (ref.read(authProvider).user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to rate this dealer.')),
      );
      return;
    }

    int selected = 0;
    final commentCtrl = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rate this dealer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Based on your own experience buying from or contacting them.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starValue = i + 1;
                  return IconButton(
                    onPressed: () => setSheetState(() => selected = starValue),
                    icon: Icon(
                      starValue <= selected ? Icons.star : Icons.star_border,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Add a comment (optional)',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: selected == 0 ? null : () => Navigator.pop(sheetContext, true),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Submit Rating'),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted != true || !context.mounted) return;

    try {
      await VehicleService.instance.submitDealerReview(
        dealerId,
        rating: selected,
        comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
      );
      ref.invalidate(dealerDetailProvider(dealerId));
      ref.invalidate(dealerReviewsProvider(dealerId));
      ref.invalidate(dealersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your rating!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit rating: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealerAsync = ref.watch(dealerDetailProvider(dealerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Dealer')),
      body: dealerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load dealer: $e')),
        data: (dealer) {
          if (dealer == null) {
            return const Center(child: Text('Dealer not found'));
          }
          final vehicles = dealer.vehicles ?? [];
          final reviewsAsync = ref.watch(dealerReviewsProvider(dealerId));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dealerDetailProvider(dealerId));
              ref.invalidate(dealerReviewsProvider(dealerId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppImage(source: dealer.logo, width: 72, height: 72),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  dealer.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (dealer.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 18, color: AppColors.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                              const SizedBox(width: 2),
                              // dealer.rating is null until a real buyer
                              // has left at least one review — shown
                              // honestly instead of a made-up default.
                              Text(
                                dealer.rating == null
                                    ? 'New dealer'
                                    : '${dealer.rating!.toStringAsFixed(1)} (${dealer.reviewCount} review${dealer.reviewCount == 1 ? '' : 's'})',
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.directions_car_outlined,
                                  size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 2),
                              Text(
                                '${dealer.totalCars} vehicles',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  dealer.location,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final currentUser = ref.watch(authProvider).user;
                    // Same check as the backend's actual enforcement
                    // (POST /dealers/:id/reviews in dealers.js) — a seller
                    // linked to THIS dealer can't rate their own dealer.
                    // This is only a UI convenience so an affiliated
                    // seller never sees a button that would just 403 —
                    // the backend check is the real gate and stays in
                    // place regardless of what this shows.
                    final isAffiliatedSeller = currentUser?.dealerId == dealer.id;
                    if (isAffiliatedSeller) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "You're linked to this dealer, so you can't rate it.",
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openRatingSheet(context, ref),
                        icon: const Icon(Icons.star_border),
                        label: const Text('Rate this dealer'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'Available Listings (${vehicles.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (vehicles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No active listings from this dealer right now.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vehicles.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    itemBuilder: (context, i) => FeaturedCarCard(vehicle: vehicles[i]),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Reviews (${dealer.reviewCount})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                reviewsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (reviews) {
                    if (reviews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No reviews yet — be the first to rate this dealer.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return Column(
                      children: reviews
                          .map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: AppImage(source: r.buyerAvatar, width: 36, height: 36),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(r.buyerName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 8),
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (i) => Icon(
                                                    i < r.rating ? Icons.star : Icons.star_border,
                                                    size: 13,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (r.comment != null && r.comment!.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(r.comment!,
                                                style: const TextStyle(color: AppColors.textSecondary)),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(
                                            DateFormat('d MMM yyyy').format(r.createdAt),
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}