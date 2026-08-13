class VehicleModel {
  final String id;
  final String name;
  final String category;
  final List<String> images;
  final String price;
  final int priceAmount;
  final String? originalPrice;
  final int? originalPriceAmount;
  final int? discountPercent;
  final bool isFeatured;
  final bool isFavorite;

  final String fuelType;
  final String transmission;
  final String year;
  final String seats;
  final String kmDriven;
  final String owners;
  final String condition;
  final String insurance;
  // The actual expiry date behind the `insurance` display string above —
  // null when there's nothing to track (insurance status isn't "Valid",
  // or this listing predates the field entirely). Used to prefill the
  // date picker in edit mode (SellVehicleScreen) without having to
  // re-parse "Valid till 12 Dec 2027" back into a DateTime, which the
  // backend only ever produced for display, not as a safe round-trip.
  final DateTime? insuranceValidTill;
  final String rcStatus;
  final String soldCount;
  final String description;
  final String location;

  final String dealerId;
  final String dealerName;
  final String? sellerId;
  final String sellerName;
  final String sellerPhone;
  final String sellerAvatar;
  final bool dealerVerified;
  final String status;

  const VehicleModel({
    required this.id,
    required this.name,
    required this.category,
    required this.images,
    required this.price,
    required this.fuelType,
    required this.transmission,
    required this.year,
    required this.seats,
    required this.kmDriven,
    required this.owners,
    required this.condition,
    required this.insurance,
    required this.rcStatus,
    required this.soldCount,
    required this.description,
    required this.location,
    required this.dealerId,
    required this.dealerName,
    required this.sellerName,
    required this.sellerPhone,
    required this.sellerAvatar,
    this.sellerId,
    this.priceAmount = 0,
    this.originalPrice,
    this.originalPriceAmount,
    this.discountPercent,
    this.isFeatured = false,
    this.dealerVerified = false,
    this.isFavorite = false,
    this.status = 'ACTIVE',
    this.insuranceValidTill,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      images: (json['images'] as List<dynamic>).map((e) => e as String).toList(),
      price: json['price'] as String,
      priceAmount: (json['priceAmount'] as num?)?.toInt() ?? 0,
      originalPrice: json['originalPrice'] as String?,
      originalPriceAmount: (json['originalPriceAmount'] as num?)?.toInt(),
      discountPercent: json['discountPercent'] as int?,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      fuelType: json['fuelType'] as String,
      transmission: json['transmission'] as String,
      year: json['year'] as String,
      seats: json['seats'] as String,
      kmDriven: json['kmDriven'] as String,
      owners: json['owners'] as String,
      condition: json['condition'] as String,
      insurance: json['insurance'] as String,
      insuranceValidTill: json['insuranceValidTill'] != null
          ? DateTime.parse(json['insuranceValidTill'] as String)
          : null,
      rcStatus: json['rcStatus'] as String,
      soldCount: json['soldCount'] as String? ?? '0',
      description: json['description'] as String,
      location: json['location'] as String,
      dealerId: json['dealerId'] as String? ?? '',
      dealerName: json['dealerName'] as String? ?? 'Independent Seller',
      sellerId: json['sellerId'] as String?,
      sellerName: json['sellerName'] as String,
      sellerPhone: json['sellerPhone'] as String,
      sellerAvatar: json['sellerAvatar'] as String? ?? 'assets/images/avatars/profile.png',
      dealerVerified: json['dealerVerified'] as bool? ?? false,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  VehicleModel copyWith({
    bool? isFavorite,
    String? status,
  }) {
    return VehicleModel(
      id: id,
      name: name,
      category: category,
      images: images,
      price: price,
      priceAmount: priceAmount,
      originalPrice: originalPrice,
      originalPriceAmount: originalPriceAmount,
      discountPercent: discountPercent,
      isFeatured: isFeatured,
      isFavorite: isFavorite ?? this.isFavorite,
      fuelType: fuelType,
      transmission: transmission,
      year: year,
      seats: seats,
      kmDriven: kmDriven,
      owners: owners,
      condition: condition,
      insurance: insurance,
      insuranceValidTill: insuranceValidTill,
      rcStatus: rcStatus,
      soldCount: soldCount,
      description: description,
      location: location,
      dealerId: dealerId,
      dealerName: dealerName,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      sellerAvatar: sellerAvatar,
      dealerVerified: dealerVerified,
      status: status ?? this.status,
    );
  }
}