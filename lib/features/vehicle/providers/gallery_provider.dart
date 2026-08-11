import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keyed by vehicle ID so switching between vehicles doesn't carry over
/// the previously selected thumbnail index.
final selectedImageProvider =
    StateProvider.autoDispose.family<int, String>((ref, vehicleId) => 0);