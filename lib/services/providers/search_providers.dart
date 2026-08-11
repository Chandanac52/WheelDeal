import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SortOption { relevance, priceLowToHigh, priceHighToLow, yearNewest }

/// Raw text typed into the search bar.
final searchQueryProvider = StateProvider<String>((ref) => "");

/// Currently selected category filter chip. "All" means no filter.
final searchCategoryProvider = StateProvider<String>((ref) => "All");

final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.relevance);
