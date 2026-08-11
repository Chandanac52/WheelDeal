import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/providers/vehicle_providers.dart';
import '../../widgets/app_image.dart';

class AllDealersScreen extends ConsumerWidget {
  const AllDealersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealers = ref.watch(dealersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Dealers')),
      body: dealers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load dealers: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No dealers yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final dealer = list[i];
              return Material(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/dealer/${dealer.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AppImage(source: dealer.logo, width: 56, height: 56),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      dealer.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (dealer.isVerified) ...[
                                    const SizedBox(width: 5),
                                    const Icon(Icons.verified, size: 15, color: AppColors.primary),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${dealer.location} · ${dealer.totalCars} vehicles',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(dealer.rating.toStringAsFixed(1)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}