import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_image.dart';

class HomeBanner extends StatelessWidget {
  final String discountText;
  final String validityText;
  final String imagePath;
  final VoidCallback? onBrowseNow;

  const HomeBanner({
    super.key,
    this.discountText = "Explore Vehicles",
    this.validityText = "Real listings, real prices",
    this.imagePath = "assets/images/cars/car4.png",
    this.onBrowseNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    discountText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  validityText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                ElevatedButton(
                  onPressed: onBrowseNow,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text("Browse Now"),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              // Was Image.asset(imagePath, ...) — only works for bundled app
              // assets. The moment a real vehicle's network photo URL
              // (http://...) got passed in here, it would silently fail to
              // load and fall back to a generic icon, no matter how correct
              // the rest of the wiring was. AppImage already handles both
              // asset paths and network URLs correctly elsewhere in the app.
              child: AppImage(
                source: imagePath,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
