import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';

class VehicleTitle extends StatelessWidget {
  final VehicleModel vehicle;

  const VehicleTitle({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FIX: this row used to end with a "★ ${vehicle.rating}" badge —
        // a per-VEHICLE rating that never had a real source (it was always
        // just a hardcoded 4.0 on every listing; see the removal of
        // Vehicle.rating in schema.prisma/vehicles.js). A star rating only
        // makes sense once someone has actually dealt with the SELLER, not
        // the listing — that's now Dealer.rating, computed live from real
        // buyer reviews and shown on the Dealer Profile screen instead.
        // Just the name here now; no badge to replace it with.
        Text(
          vehicle.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              vehicle.price,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (vehicle.originalPrice != null) ...[
              const SizedBox(width: 10),
              Text(
                vehicle.originalPrice!,
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${vehicle.soldCount} Sold",
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}