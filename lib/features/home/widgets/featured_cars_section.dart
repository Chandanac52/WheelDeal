import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers/vehicle_providers.dart';
import 'featured_car_card.dart';
import 'section_title.dart';

class FeaturedCarsSection extends ConsumerWidget {
  final VoidCallback? onSeeAll;

  const FeaturedCarsSection({super.key, this.onSeeAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredVehiclesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: "Featured Vehicles"),
            TextButton(onPressed: onSeeAll, child: const Text("See all")),
          ],
        ),
        const SizedBox(height: 4),
        featured.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => const Text('Could not load vehicles'),
          data: (vehicles) {
            final list = vehicles.isEmpty
                ? ref.watch(vehiclesProvider).valueOrNull ?? []
                : vehicles;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                return FeaturedCarCard(vehicle: list[index]);
              },
            );
          },
        ),
      ],
    );
  }
}