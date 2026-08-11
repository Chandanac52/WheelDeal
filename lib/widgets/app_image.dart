import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Displays asset paths, network URLs, local on-device file paths, or a
/// fallback placeholder.
class AppImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  bool get _isNetwork =>
      source.startsWith('http://') || source.startsWith('https://');

  bool get _isAsset => source.startsWith('assets/');

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.border,
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_car_rounded,
        size: (height ?? 48) * 0.35,
        color: AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isNetwork) {
      child = CachedNetworkImage(
        imageUrl: source,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      );
    } else if (_isAsset) {
      child = Image.asset(
        source,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      // Anything else is treated as a local on-device file path — e.g. a
      // photo just picked from the gallery/camera, shown as an instant
      // preview while it's still uploading (see ProfileScreen's avatar
      // picker). Never a value we send to the server as-is: a local path
      // is meaningless off the device it came from.
      child = Image.file(
        File(source),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    return child;
  }
}