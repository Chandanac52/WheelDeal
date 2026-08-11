import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dealer_model.dart';
import '../../models/vehicle_model.dart';
import '../repositories/vehicle_service.dart';
import 'search_providers.dart';

final vehicleServiceProvider = Provider<VehicleService>((ref) => VehicleService.instance);

final vehiclesProvider = FutureProvider<List<VehicleModel>>((ref) async {
  return VehicleService.instance.getAll();
});

final featuredVehiclesProvider = FutureProvider<List<VehicleModel>>((ref) async {
  return VehicleService.instance.getFeatured();
});

final dealersProvider = FutureProvider<List<DealerModel>>((ref) async {
  return VehicleService.instance.getDealers();
});

/// Powers the Dealer Profile screen — dealer info plus their active
/// listings, unlike dealersProvider which only carries the summary fields
/// needed for the Home "Popular Dealers" cards.
final dealerDetailProvider = FutureProvider.family<DealerModel?, String>((ref, id) async {
  return VehicleService.instance.getDealerById(id);
});

/// The list of actual buyer reviews for one dealer — separate from
/// dealerDetailProvider since dealer.rating/reviewCount (the summary
/// numbers) come back with the dealer itself, while the full review list
/// is only needed once someone opens the "Reviews" section on that
/// dealer's profile.
final dealerReviewsProvider = FutureProvider.family<List<DealerReviewModel>, String>((ref, dealerId) async {
  return VehicleService.instance.getDealerReviews(dealerId);
});

final vehicleDetailProvider = FutureProvider.family<VehicleModel?, String>((ref, id) async {
  return VehicleService.instance.getById(id);
});

final myListingsProvider = FutureProvider<List<VehicleModel>>((ref) async {
  return VehicleService.instance.getMyListings();
});

/// Derives the filtered + sorted vehicle list from query + category + sort.
final searchResultsProvider = FutureProvider<List<VehicleModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final category = ref.watch(searchCategoryProvider);
  final sort = ref.watch(sortOptionProvider);

  return VehicleService.instance.getAll(
    query: query.isEmpty ? null : query,
    category: category,
    sort: sort,
  );
});