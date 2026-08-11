import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/providers/search_providers.dart';

void showSortSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final current = ref.read(sortOptionProvider);
      const options = {
        SortOption.relevance: "Relevance",
        SortOption.priceLowToHigh: "Price: Low to High",
        SortOption.priceHighToLow: "Price: High to Low",
        SortOption.yearNewest: "Year: Newest First",
      };

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sort by",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...options.entries.map(
                (entry) => RadioListTile<SortOption>(
                  value: entry.key,
                  groupValue: current,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  onChanged: (value) {
                    ref.read(sortOptionProvider.notifier).state = value!;
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
