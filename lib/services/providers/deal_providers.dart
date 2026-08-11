import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vehicle_model.dart';
import 'vehicle_providers.dart';

/// The single vehicle with the largest genuine discount in the current
/// active catalog — used to power the Home screen's promo banner with a
/// real "X% Off" instead of a hardcoded placeholder. Reuses whatever
/// vehiclesProvider has already fetched rather than making a separate
/// network call.
///
/// Returns null when nothing in the catalog currently has a real discount
/// (no listing has an originalPrice set higher than its price), in which
/// case the banner falls back to a generic "browse everything" state
/// instead of ever showing a fake or stale number.
final bestDealProvider = Provider<VehicleModel?>((ref) {
  final vehicles = ref.watch(vehiclesProvider).valueOrNull ?? const [];
  final discounted = vehicles.where((v) => (v.discountPercent ?? 0) > 0).toList();
  if (discounted.isEmpty) return null;
  discounted.sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
  return discounted.first;
});
