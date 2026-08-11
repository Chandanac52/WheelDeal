import 'vehicle_model.dart';

class DealerModel {
  final String id;
  final String name;
  final String logo;
  final double rating;
  final int totalCars;
  final String location;
  final bool isVerified;
  // Only present when fetched via getDealerById (the Dealer Profile
  // screen) — null for entries from the Home "Popular Dealers" list, which
  // only ever needs the summary fields above.
  final List<VehicleModel>? vehicles;

  const DealerModel({
    required this.id,
    required this.name,
    required this.logo,
    required this.rating,
    required this.totalCars,
    required this.location,
    this.isVerified = false,
    this.vehicles,
  });

  factory DealerModel.fromJson(Map<String, dynamic> json) {
    return DealerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      logo: json['logo'] as String? ?? 'assets/images/dealers/dealer1.png',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      totalCars: json['totalCars'] as int? ?? 0,
      location: json['location'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      vehicles: json['vehicles'] == null
          ? null
          : (json['vehicles'] as List<dynamic>)
              .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}