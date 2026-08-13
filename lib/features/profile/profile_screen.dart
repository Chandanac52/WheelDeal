import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../models/vehicle_model.dart';
import '../../services/providers/auth_provider.dart';
import '../../services/providers/favorites_provider.dart';
import '../../services/providers/notification_providers.dart';
import '../../services/providers/vehicle_providers.dart';
import '../../services/repositories/vehicle_service.dart';
import '../../widgets/app_image.dart';
import '../home/widgets/featured_car_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Purely a local, on-device preview of the photo just picked — shown
  // immediately so the tap feels instant, swapped back to null once the
  // real upload finishes and `user.avatar` reflects the new URL. This value
  // NEVER gets sent to updateProfile: a device file path means nothing off
  // the phone it came from, and briefly writing it to the server as the
  // user's "avatar" would leave a URL nobody else could actually load.
  File? _localAvatarPreview;
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _localAvatarPreview = file;
      _uploadingAvatar = true;
    });

    try {
      // Reuses the same generic /upload endpoint the Sell form uses for
      // listing photos — it already resizes/compresses and returns a public
      // URL, so there's nothing avatar-specific needed on the backend.
      final urls = await VehicleService.instance.uploadImages([file]);
      await ref.read(authProvider.notifier).updateProfile(avatar: urls.first);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _localAvatarPreview = null;
          _uploadingAvatar = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!auth.isAuthenticated) {
      return const SafeArea(child: _SignedOutProfileView());
    }

    final user = auth.user!;
    final favorites = ref.watch(favoriteVehiclesProvider);
    final myListings = ref.watch(myListingsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _changeAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: _localAvatarPreview != null
                            // Instant local preview of what was just picked —
                            // shown while the real upload is still in flight.
                            ? Image.file(_localAvatarPreview!, width: 72, height: 72, fit: BoxFit.cover)
                            : AppImage(
                                source: user.avatar ?? 'assets/images/avatars/profile.png',
                                width: 72,
                                height: 72,
                              ),
                      ),
                      if (_uploadingAvatar)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      // Only ever one identity string shown here (phone, or
                      // email as a fallback for any legacy account that
                      // still has one) — never printed twice.
                      Text(user.phone ?? user.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditProfile(context, ref, user.name, user.phone),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MenuTile(
              icon: Icons.favorite_border,
              title: 'My Favorites',
              subtitle: 'Saved vehicles',
              onTap: () => _showFavorites(context, ref),
            ),
            _MenuTile(
              icon: Icons.directions_car_outlined,
              title: 'My Listings',
              subtitle: 'Vehicles you listed for sale',
              onTap: () => _showMyListings(context, ref, myListings),
            ),
            _MenuTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              // The subtitle doubles as a live unread indicator — falls
              // back to the static description while the count loads or if
              // it fails, so this never looks broken.
              subtitle: ref.watch(unreadNotificationCountProvider).when(
                    data: (count) => count > 0 ? '$count new' : 'Price drops & messages',
                    loading: () => 'Price drops & messages',
                    error: (_, _) => 'Price drops & messages',
                  ),
              onTap: () => context.push('/notifications'),
            ),
            _MenuTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQ, contact us',
              onTap: () => context.push('/help-support'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out successfully')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Sign Out'),
              ),
            ),
            const SizedBox(height: 20),
            favorites.when(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Favorites',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          // FeaturedCarCard is sized everywhere else (Home,
                          // Search) inside a GridView with
                          // childAspectRatio: 0.68, i.e. height ≈ width ÷
                          // 0.68. At width 170 that's ~250.
                          height: 250,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 14),
                            itemBuilder: (_, i) => SizedBox(
                              width: 170,
                              child: FeaturedCarCard(vehicle: list[i]),
                            ),
                          ),
                        ),
                      ],
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref, String name, String? phone) {
    final nameCtrl = TextEditingController(text: name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            // Phone is the verified sign-in identity (proven via Firebase
            // OTP at login) — changing it isn't a profile edit, it's
            // effectively switching accounts, which has to go through OTP
            // verification for the new number, not a text field here.
            // Shown read-only so the person can still see what number
            // they're signed in as, without any implication it can be
            // typed over. AuthNotifier.updateProfile (auth_provider.dart)
            // and PUT /me (auth.js) both deliberately have no `phone`
            // parameter anymore — this UI has to match, or the Save button
            // below would be calling a signature that doesn't exist.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phone', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(phone ?? 'Not set', style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authProvider.notifier).updateProfile(
                      name: nameCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFavorites(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(favoriteVehiclesProvider);
    favorites.whenData((list) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, controller) => list.isEmpty
              ? const Center(child: Text('No favorites yet'))
              : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FeaturedCarCard(vehicle: list[i]),
                  ),
                ),
        ),
      );
    });
  }

  void _showMyListings(BuildContext context, WidgetRef ref, AsyncValue myListings) {
    myListings.when(
      data: (list) {
        showModalBottomSheet(
          context: context,
          // The default modal bottom sheet's own drag-to-dismiss gesture
          // only works if there's nothing scrollable filling the sheet — a
          // plain fixed-height ListView (as this used to be) swallows the
          // drag for its own scrolling instead, so dragging down never
          // dismissed the sheet. showDragHandle gives a visible grip area,
          // and DraggableScrollableSheet (same pattern _showFavorites above
          // already uses) makes the list hand off "drag down while already
          // at the top" into dismissing the sheet, instead of doing nothing.
          showDragHandle: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // Named sheetContext deliberately, not context — every row inside
          // reuses the OUTER `context` (this method's own parameter, which
          // belongs to ProfileScreen and stays mounted regardless of this
          // sheet's lifecycle) for anything that happens AFTER the sheet
          // closes: pushing to a listing's details/edit screen, or showing
          // a SnackBar once a delete finishes. sheetContext is used only to
          // pop the sheet itself or show something that lives strictly
          // within its own lifetime (like the delete confirm dialog). Using
          // the sheet's own context for post-close actions is exactly the
          // bug found and fixed in contact_button.dart's Contact Seller
          // sheet — a slow enough action (a real network delete, for
          // instance) can outlast the sheet's closing animation, leaving
          // that context unmounted and silently swallowing whatever came
          // after it.
          builder: (sheetContext) => list.isEmpty
              ? const SizedBox(
                  height: 200,
                  child: Center(child: Text('No listings yet. Tap Sell to add one.')),
                )
              : DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.55,
                  minChildSize: 0.3,
                  maxChildSize: 0.9,
                  builder: (innerContext, scrollController) => ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final vehicle = list[i];
                      final isSold = vehicle.status == 'SOLD';
                      return ListTile(
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                vehicle.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // A sold listing used to be indistinguishable
                            // from an active one here — nothing showed the
                            // seller it was no longer live, or hinted that
                            // relisting was even possible.
                            if (isSold) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.textPrimary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SOLD',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text('${vehicle.price} • ${vehicle.location}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Editing details (price, mileage, description,
                            // etc.) is now its own explicit icon, separate
                            // from the row tap below — this is the SAME
                            // screen as "Sell" (SellVehicleScreen, reused
                            // via editVehicleId — see app_router.dart), not
                            // a distinct "edit vehicle" screen.
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                              tooltip: 'Edit details',
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                context.push('/edit-vehicle/${vehicle.id}');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              tooltip: 'Delete listing',
                              onPressed: () => _confirmDeleteListing(sheetContext, context, ref, vehicle),
                            ),
                          ],
                        ),
                        // FIX: this used to push straight to
                        // '/edit-vehicle/${vehicle.id}' — the details FORM,
                        // which has no status indicator and no way to
                        // relist. "Mark as Sold" / "Relist This Vehicle"
                        // only ever lived on the vehicle DETAILS page
                        // (_OwnerActionBar in vehicle_details_screen.dart)
                        // — a seller tapping a sold listing here had no
                        // visible way back to it. The row now opens the
                        // details page instead, where that button already
                        // works correctly; editing the listing's fields is
                        // still one tap away via the pencil icon above.
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.push('/vehicle/${vehicle.id}');
                        },
                      );
                    },
                  ),
                ),
        );
      },
      loading: () {},
      error: (_, _) {},
    );
  }

  /// Confirms, then permanently deletes one of the seller's own listings.
  /// [sheetContext] is only ever used to show the confirm dialog and to pop
  /// the sheet — [context] (the durable, outer ProfileScreen context) is
  /// what every post-close action (refreshing lists, showing the result)
  /// runs against. See the comment on _showMyListings above for why that
  /// split matters here specifically, since the delete call is a real
  /// network round trip.
  Future<void> _confirmDeleteListing(
    BuildContext sheetContext,
    BuildContext context,
    WidgetRef ref,
    VehicleModel vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text("${vehicle.name} will be permanently removed and can't be recovered."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Close the sheet before the network call — a delete that takes a
    // moment shouldn't leave the sheet hanging open showing a list that's
    // about to be stale.
    if (sheetContext.mounted) Navigator.pop(sheetContext);

    try {
      await VehicleService.instance.deleteListing(vehicle.id);
      // Refresh everywhere this vehicle could still be showing: the
      // seller's own My Listings, Home's general + featured feeds, Search
      // results, its own now-gone detail page, and — if it was a
      // dealer-affiliated listing — that dealer's profile too, the same
      // set of places "Mark as Sold" already refreshes.
      ref.invalidate(myListingsProvider);
      ref.invalidate(vehiclesProvider);
      ref.invalidate(featuredVehiclesProvider);
      ref.invalidate(searchResultsProvider);
      ref.invalidate(vehicleDetailProvider(vehicle.id));
      ref.invalidate(dealerDetailProvider(vehicle.dealerId));
      ref.invalidate(dealersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${vehicle.name} deleted'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete listing: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

/// Shown on ProfileScreen when nobody's signed in — replaces the old bare
/// "Sign in to access your profile" + button with an actual value prop
/// (what signing in gets you) so the button has context instead of just
/// gatekeeping the tab. Purely presentational; nothing here reads or
/// writes any state.
class _SignedOutProfileView extends StatelessWidget {
  const _SignedOutProfileView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your account, one tap away',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to save vehicles, manage your listings, and chat directly with sellers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 28),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BenefitChip(icon: Icons.favorite_border, label: 'Favorites'),
                SizedBox(width: 12),
                _BenefitChip(icon: Icons.directions_car_outlined, label: 'Listings'),
                SizedBox(width: 12),
                _BenefitChip(icon: Icons.chat_bubble_outline, label: 'Chats'),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Takes less than a minute — just your phone number.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One small icon-over-label pill used in the signed-out value-prop row
/// above — a quiet preview of what each feature is, not a live control
/// (none of these navigate or do anything on their own).
class _BenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}