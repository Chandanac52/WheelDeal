class UserModel {
  final String id;
  final String? email;
  final String name;
  final String? phone;
  final String? avatar;
  final String role;

  const UserModel({
    required this.id,
    this.email,
    required this.name,
    this.phone,
    this.avatar,
    this.role = 'BUYER',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] as String? ?? 'BUYER',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'avatar': avatar,
        'role': role,
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
    );
  }
}
