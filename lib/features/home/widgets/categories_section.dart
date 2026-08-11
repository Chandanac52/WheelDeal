import 'package:flutter/material.dart';

import 'category_chip.dart';
import 'section_title.dart';

class CategoriesSection extends StatefulWidget {
  final ValueChanged<String>? onCategorySelected;
  final VoidCallback? onSeeAll;

  const CategoriesSection({super.key, this.onCategorySelected, this.onSeeAll});

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
  String _selected = "See All";

  static const _categories = <String, IconData?>{
    "See All": Icons.grid_view_rounded,
    "Cars": Icons.directions_car_filled_rounded,
    "Bikes": Icons.two_wheeler_rounded,
    "Scooters": Icons.electric_moped_rounded,
    "Auto Rickshaw": Icons.electric_rickshaw_rounded,
    "Trucks": Icons.local_shipping_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: "Category"),
            TextButton(
              onPressed: widget.onSeeAll,
              child: const Text("See all"),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final entry = _categories.entries.elementAt(index);
              return CategoryChip(
                title: entry.key,
                icon: entry.value,
                isSelected: _selected == entry.key,
                onTap: () {
                  setState(() => _selected = entry.key);
                  widget.onCategorySelected?.call(entry.key);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}