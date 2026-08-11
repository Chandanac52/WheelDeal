import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/providers/auth_provider.dart';
import '../../../services/providers/vehicle_providers.dart';
import '../../../services/repositories/vehicle_service.dart';
import '../widgets/chat_start_helper.dart';
import '../widgets/contact_button.dart';
import '../widgets/dealer_card.dart';
import '../widgets/image_gallery.dart';
import '../widgets/vehicle_description.dart';
import '../widgets/vehicle_header.dart';
import '../widgets/vehicle_specs.dart';
import '../widgets/vehicle_title.dart';

class VehicleDetailsScreen extends ConsumerWidget {
  final String vehicleId;

  const VehicleDetailsScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));

    return vehicleAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Could not load vehicle")),
      ),
      data: (vehicle) {
        if (vehicle == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Vehicle not found")),
            body: const Center(child: Text("This listing is no longer available.")),
          );
        }

        return _DetailsBody(vehicle: vehicle);
      },
    );
  }
}

class _DetailsBody extends ConsumerStatefulWidget {
  final VehicleModel vehicle;

  const _DetailsBody({required this.vehicle});

  @override
  ConsumerState<_DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends ConsumerState<_DetailsBody> {
  bool _updatingStatus = false;

  Future<void> _setStatus(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await VehicleService.instance.updateVehicleStatus(widget.vehicle.id, status);
      // Refresh everywhere this vehicle (or lists containing it) could be
      // showing: its own detail page, Home's general + featured feeds,
      // Search results, and the seller's own My Listings — plus the
      // seller's "N Sold" badge, which lives on every OTHER vehicle of
      // theirs too, not just this one.
      ref.invalidate(vehicleDetailProvider(widget.vehicle.id));
      ref.invalidate(vehiclesProvider);
      ref.invalidate(featuredVehiclesProvider);
      ref.invalidate(searchResultsProvider);
      ref.invalidate(myListingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'SOLD' ? 'Marked as sold.' : 'Relisted — it\'s active again.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _confirmMarkSold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as sold?'),
        content: Text(
          "${widget.vehicle.name} will be removed from Search and Home, and buyers won't be able to contact you about it anymore. You can relist it later if needed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark as Sold'),
          ),
        ],
      ),
    );
    if (confirmed == true) _setStatus('SOLD');
  }

  // Same gate the Contact Seller sheet uses — this DealerCard's Call
  // button is a separate entry point from that sheet, so without this it
  // could still be used to place a call anonymously even after Contact
  // Seller itself was locked behind sign-in.
  Future<void> _handleCall() async {
    final vehicle = widget.vehicle;
    if (await ensureSignedIn(context, ref)) {
      launchTel(vehicle.sellerPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final auth = ref.watch(authProvider);
    final isOwner = auth.user?.id != null && auth.user!.id == vehicle.sellerId;
    final isSold = vehicle.status == 'SOLD';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VehicleHeaderOverlay(vehicleId: vehicle.id),
              const SizedBox(height: 12),
              ImageGallery(
                vehicleId: vehicle.id,
                images: vehicle.images,
              ),
              if (isSold) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SOLD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              VehicleTitle(vehicle: vehicle),
              const SizedBox(height: 22),
              const Text(
                "Specifications",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              VehicleSpecs(vehicle: vehicle),
              const SizedBox(height: 24),
              VehicleDescription(description: vehicle.description),
              const SizedBox(height: 24),
              // A seller viewing their own listing gets no Call/Chat
              // buttons for themselves — that never made sense — DealerCard
              // is only shown to buyers looking at someone else's listing.
              if (!isOwner) ...[
                DealerCard(
                  vehicle: vehicle,
                  onCall: _handleCall,
                  onChat: () => openChatWithSeller(context, ref, vehicle),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: isOwner
            ? _OwnerActionBar(
                isSold: isSold,
                updating: _updatingStatus,
                onMarkSold: _confirmMarkSold,
                onRelist: () => _setStatus('ACTIVE'),
              )
            : ContactButton(vehicle: vehicle),
      ),
    );
  }
}

class _OwnerActionBar extends StatelessWidget {
  final bool isSold;
  final bool updating;
  final VoidCallback onMarkSold;
  final VoidCallback onRelist;

  const _OwnerActionBar({
    required this.isSold,
    required this.updating,
    required this.onMarkSold,
    required this.onRelist,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ElevatedButton(
          onPressed: updating ? null : (isSold ? onRelist : onMarkSold),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: isSold ? AppColors.textSecondary : AppColors.primary,
          ),
          child: updating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isSold ? 'Relist This Vehicle' : 'Mark as Sold'),
        ),
      ),
    );
  }
}