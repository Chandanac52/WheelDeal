import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../repositories/vehicle_service.dart';

/// Holds the set of favourited vehicle IDs.
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier(this._ref) : super({}) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    if (ApiConstants.useMockData) return;
    try {
      final ids = await VehicleService.instance.getFavoriteIds();
      state = ids.toSet();
    } catch (_) {}
  }

  bool isFavorite(String vehicleId) => state.contains(vehicleId);

  Future<void> toggle(String vehicleId) async {
    final wasFavorite = state.contains(vehicleId);

    // Update the UI immediately (optimistic) — don't make the user wait for
    // a round trip just to see the heart icon fill in.
    state = wasFavorite
        ? ({...state}..remove(vehicleId))
        : ({...state}..add(vehicleId));

    if (ApiConstants.useMockData) return;

    try {
      if (wasFavorite) {
        await VehicleService.instance.removeFavorite(vehicleId);
      } else {
        await VehicleService.instance.addFavorite(vehicleId);
      }
    } catch (_) {
      // Roll back silently on failure (offline, expired session, etc.) —
      // whoever's watching favoritesProvider will see the heart revert.
      state = wasFavorite
          ? ({...state}..add(vehicleId))
          : ({...state}..remove(vehicleId));
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier(ref),
);

final favoriteVehiclesProvider = FutureProvider((ref) async {
  final favIds = ref.watch(favoritesProvider);
  final all = await VehicleService.instance.getAll();
  return all.where((v) => favIds.contains(v.id)).toList();
});
