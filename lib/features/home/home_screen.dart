import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/providers/deal_providers.dart';
import '../../services/providers/nav_providers.dart';
import '../../services/providers/search_providers.dart';
import 'widgets/categories_section.dart';
import 'widgets/dealers_section.dart';
import 'widgets/featured_cars_section.dart';
import 'widgets/home_banner.dart';
import 'widgets/notification_bell_button.dart';
import 'widgets/search_bar_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _goToSearch(WidgetRef ref, {String? query}) {
    if (query != null) {
      ref.read(searchQueryProvider.notifier).state = query;
    }
    ref.read(mainTabIndexProvider.notifier).state = 1; // Search tab
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The single vehicle with the biggest genuine discount right now, or
    // null if nothing in the catalog currently has a real one. Powers the
    // banner below with actual data instead of the hardcoded "20% Off /
    // Until Aug 15" placeholder it used to always show regardless of what
    // was actually in the catalog.
    final bestDeal = ref.watch(bestDealProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchBarWidget(
                      onTap: () => _goToSearch(ref),
                      onChanged: (value) => _goToSearch(ref, query: value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const NotificationBellButton(),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Give it a second life.\nDiscover value beyond new.",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              HomeBanner(
                discountText:
                    bestDeal != null ? '${bestDeal.discountPercent}% Off' : 'Explore Vehicles',
                validityText: bestDeal != null ? 'On ${bestDeal.name}' : 'Real listings, real prices',
                imagePath: (bestDeal != null && bestDeal.images.isNotEmpty)
                    ? bestDeal.images.first
                    : 'assets/images/cars/car4.png',
                // Was completely unwired before (const HomeBanner() with no
                // callback at all) — tapping "Browse Now" did nothing.
                // Now: if there's a real best deal, go straight to it;
                // otherwise fall back to a general browse via Search.
                onBrowseNow: () {
                  if (bestDeal != null) {
                    context.push('/vehicle/${bestDeal.id}');
                  } else {
                    _goToSearch(ref);
                  }
                },
              ),
              const SizedBox(height: 28),
              CategoriesSection(
                onCategorySelected: (category) {
                  final mapped = category == 'See All' ? 'All' : category;
                  ref.read(searchCategoryProvider.notifier).state = mapped;
                  _goToSearch(ref);
                },
                // "See all" next to Category — same destination as tapping
                // the "See All" chip itself: full catalog, no category
                // filter. Previously this button had no onPressed at all,
                // so tapping it did nothing.
                onSeeAll: () {
                  ref.read(searchCategoryProvider.notifier).state = 'All';
                  _goToSearch(ref);
                },
              ),
              const SizedBox(height: 30),
              FeaturedCarsSection(
                // "See all" next to Featured Vehicles: there's no separate
                // "featured only" filter in Search, so this takes you to
                // the same full browsing experience — clears any leftover
                // category filter so it truly shows everything, not a
                // scoped-down view. Previously this button had no
                // onPressed at all, so tapping it did nothing.
                onSeeAll: () {
                  ref.read(searchCategoryProvider.notifier).state = 'All';
                  _goToSearch(ref);
                },
              ),
              const SizedBox(height: 30),
              const DealersSection(),
            ],
          ),
        ),
      ),
    );
  }
}