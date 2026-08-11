import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../services/providers/vehicle_providers.dart';
import '../../widgets/app_image.dart';
import '../home/widgets/featured_car_card.dart';

class DealerProfileScreen extends ConsumerWidget {
  final String dealerId;

  const DealerProfileScreen({super.key, required this.dealerId});

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

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dealerDetailProvider(dealerId)),
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
                              Text(dealer.rating.toStringAsFixed(1)),
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
              ],
            ),
          );
        },
      ),
    );
  }
}