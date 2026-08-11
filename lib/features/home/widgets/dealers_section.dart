import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/providers/vehicle_providers.dart';
import 'dealer_card.dart';
import 'section_title.dart';

class DealersSection extends ConsumerWidget {
  const DealersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealers = ref.watch(dealersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: "Popular Dealers"),
            // FIX: this used to be onPressed: () {} — went nowhere.
            TextButton(
              onPressed: () => context.push('/dealers'),
              child: const Text("See all"),
            ),
          ],
        ),
        const SizedBox(height: 4),
        dealers.when(
          loading: () => const SizedBox(
            height: 198,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => SizedBox(
            height: 198,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final dealer = list[index];
                // FIX: DealerCard itself has no onTap — wrapping it here
                // is what makes each card actually navigate to that
                // dealer's profile instead of doing nothing when tapped.
                return GestureDetector(
                  onTap: () => context.push('/dealer/${dealer.id}'),
                  child: DealerCard(dealer: dealer),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}