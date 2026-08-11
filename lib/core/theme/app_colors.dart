import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary (mustard / gold — matches banner button, prices, active chip)
  static const Color primary = Color(0xFFD9932A);
  static const Color primaryDark = Color(0xFFB9781A);
  static const Color primaryLight = Color(0xFFFBEBD1);

  // Background Colors (warm cream, not stark white)
  static const Color background = Color(0xFFF7F2EA);
  static const Color surface = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF241A12);
  static const Color textSecondary = Color(0xFF8A7E70);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE3F2E5);
  static const Color warning = Color(0xFFD9932A);
  static const Color error = Color(0xFFC62828);
  static const Color favorite = Color(0xFFE04B4B);

  // Badges
  static const Color featuredBadge = Color(0xFF241A12);
  static const Color discountBadge = Color(0xFFD9932A);

  // Others
  static const Color border = Color(0xFFEDE4D3);
  static const Color divider = Color(0xFFF0EAE0);
  static const Color chipBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFEFE8DA);
}