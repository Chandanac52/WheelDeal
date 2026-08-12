class UserModel {
  final String id;
  final String? email;
  final String name;
  final String? phone;
  final String? avatar;
  final String role;
  // Which dealer (if any) this account is authorized to sell on behalf of
  // — mirrors User.dealerId in schema.prisma. Null for an individual
  // seller/buyer. Currently only used to hide the "Rate this dealer"
  // button on DealerProfileScreen for a seller viewing the dealer they're
  // themselves linked to (see dealer_profile_screen.dart) — the backend
  // (POST /dealers/:id/reviews in dealers.js) is still the actual
  // enforcement; this is only ever a UI convenience on top of that, never
  // a substitute for it, since a client-side field is trivially spoofable.
  final String? dealerId;

  const UserModel({
    required this.id,
    this.email,
    required this.name,
    this.phone,
    this.avatar,
    this.role = 'BUYER',
    this.dealerId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] as String? ?? 'BUYER',
      dealerId: json['dealerId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'avatar': avatar,
        'role': role,
        'dealerId': dealerId,
      };

  UserModel copyWith({
    String? name,
    String? phone,
    String? avatar,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      role: role,
      dealerId: dealerId,
    );
  }
}