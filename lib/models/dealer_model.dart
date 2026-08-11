import 'vehicle_model.dart';

class DealerModel {
  final String id;
  final String name;
  final String logo;
  // Null means this dealer has no reviews yet — never coerced to a
  // fallback number like 4.5. The backend (dealers.js) computes this live
  // from real Review rows and only includes a value once at least one
  // buyer has actually left one; UI should show something like "New" or
  // "No ratings yet" when this is null, not "0.0" or a made-up default.
  final double? rating;
  final int reviewCount;
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
    required this.totalCars,
    required this.location,
    this.rating,
    this.reviewCount = 0,
    this.isVerified = false,
    this.vehicles,
  });

  factory DealerModel.fromJson(Map<String, dynamic> json) {
    return DealerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      logo: json['logo'] as String? ?? 'assets/images/dealers/dealer1.png',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int? ?? 0,
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

/// One buyer's review of a dealer — shown in the Dealer Profile screen's
/// review list (fetched via VehicleService.getDealerReviews) and produced
/// by submitting one via VehicleService.submitDealerReview.
class DealerReviewModel {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String buyerId;
  final String buyerName;
  final String buyerAvatar;

  const DealerReviewModel({
    required this.id,
    required this.rating,
    required this.createdAt,
    required this.buyerId,
    required this.buyerName,
    required this.buyerAvatar,
    this.comment,
  });

  factory DealerReviewModel.fromJson(Map<String, dynamic> json) {
    return DealerReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      buyerId: json['buyerId'] as String,
      buyerName: json['buyerName'] as String,
      buyerAvatar: json['buyerAvatar'] as String? ?? 'assets/images/avatars/profile.png',
    );
  }
}