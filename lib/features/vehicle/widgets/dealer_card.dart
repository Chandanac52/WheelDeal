import 'package:flutter/material.dart';

import '../../../widgets/app_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';

/// Seller information card shown on the Vehicle Details screen
/// (avatar, name, dealer, location, Call + Chat buttons).
class DealerCard extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  const DealerCard({
    super.key,
    required this.vehicle,
    this.onCall,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Seller Information",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: AppImage(
                  source: vehicle.sellerAvatar,
                  width: 52,
                  height: 52,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vehicle.sellerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (vehicle.dealerVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.primary),
                        ],
                      ],
                    ),
                    Text(
                      vehicle.dealerName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    // FIX: this used to show "${vehicle.rating} · listings"
                    // here — a per-VEHICLE rating that never had a real
                    // source (see VehicleModel/schema.prisma: there's no
                    // such thing anymore). A star rating only makes sense
                    // once someone has actually dealt with the SELLER, not
                    // the listing, and that's now shown on the Dealer
                    // Profile screen instead (dealer.rating, computed live
                    // from real reviews) — this card just links there via
                    // the dealer name above; it doesn't duplicate a number
                    // here that this screen has no honest way to produce
                    // for an individual (non-dealer) seller anyway.
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  vehicle.location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text("Call"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text("Chat"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}