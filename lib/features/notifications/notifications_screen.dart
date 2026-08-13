import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/providers/chat_providers.dart';
import '../../services/providers/notification_providers.dart';
import '../../services/repositories/vehicle_service.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  // Small local relative-time formatter — avoids pulling in a whole new
  // package dependency (like `timeago`) just for this one label.
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'price_drop':
        return Icons.trending_down;
      case 'callback':
        return Icons.phone_callback_outlined;
      case 'sold':
        return Icons.sell_outlined;
      case 'expired':
        return Icons.event_busy_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'message':
        return AppColors.primary;
      case 'price_drop':
        return AppColors.success;
      case 'callback':
        return const Color(0xFF7C5FCC);
      case 'sold':
        return AppColors.textSecondary;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  // The backend collapses repeat callback requests from the same buyer
  // about the same vehicle into one updating row rather than a new row
  // per request (see the upsert in vehicles.js) — n.count is how many
  // times that's happened. A request from a different buyer, or about a
  // different vehicle, is always its own separate row with its own count
  // starting at 1, so this only ever shows a number when it's genuinely
  // the same person asking again.
  String _titleFor(NotificationModel n) {
    return n.count > 1 ? '${n.title} (${n.count})' : n.title;
  }

  Future<void> _callBack(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// FIX: a 'callback' notification used to just navigate to the vehicle
  /// page like any other notification — which told the seller nothing
  /// they could actually act on. This gives them the one thing that
  /// matters: a number to call, one tap away, with the listing it's about
  /// still reachable underneath if they want it.
  void _showCallBackSheet(BuildContext context, NotificationModel n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Named sheetContext deliberately, not context — using the outer
      // `context` (passed into this method, durable across the sheet's own
      // lifecycle) for the pop-then-navigate/call actions below is what
      // keeps this reliable even if a slow action outlasts the sheet's
      // closing animation. Popping the sheet still uses sheetContext.
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Callback request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(n.body, style: const TextStyle(color: AppColors.textSecondary)),
              // Surfaces the same repeat-count the list row shows, spelled
              // out — a quiet nudge that this specific person has already
              // asked more than once and is still waiting to hear back.
              if (n.count > 1) ...[
                const SizedBox(height: 6),
                Text(
                  'Requested ${n.count} times',
                  style: const TextStyle(
                    color: Color(0xFF7C5FCC),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (n.relatedPhone != null && n.relatedPhone!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _callBack(n.relatedPhone!);
                    },
                    icon: const Icon(Icons.call),
                    label: Text('Call ${n.relatedPhone}'),
                  ),
                )
              else
                const Text(
                  'No phone number was provided with this request.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              if (n.relatedVehicleId != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/vehicle/${n.relatedVehicleId}');
                    },
                    child: const Text('View listing'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref, NotificationModel n) async {
    if (!n.read) {
      // Optimistic: flip it locally right away rather than waiting on the
      // network round trip, same pattern as elsewhere in this app.
      await VehicleService.instance.markNotificationRead(n.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
    if (!context.mounted) return;

    if (n.type == 'message' && n.relatedChatId != null) {
      context.push('/chat/${n.relatedChatId}');
    } else if (n.type == 'callback') {
      _showCallBackSheet(context, n);
    } else if ((n.type == 'price_drop' || n.type == 'sold' || n.type == 'expired') &&
        n.relatedVehicleId != null) {
      // An 'expired' listing is still viewable too, same as 'sold' —
      // vehicle_details_screen.dart shows a banner for it and the owner
      // action bar there is what actually lets the seller relist once
      // they've updated the insurance date.
      context.push('/vehicle/${n.relatedVehicleId}');
    }
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    await VehicleService.instance.markAllNotificationsRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    // markAllNotificationsRead() also marks the underlying chat messages
    // read on the server (see notifications.js) — without also refreshing
    // this, the per-chat dots on the Messages list would stay on until you
    // separately opened each conversation.
    ref.invalidate(chatsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 56, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      "You're all caught up",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          // No Divider between rows — same card-row treatment as the Chats
          // list now, for a consistent look across both: rounded rows with
          // spacing between them and a subtle tint while unread, instead of
          // a hard separator line under every entry.
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final n = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: n.read ? Colors.transparent : AppColors.primaryLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _handleTap(context, ref, n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _colorFor(n.type).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconFor(n.type), color: _colorFor(n.type), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleFor(n),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: n.read ? FontWeight.w600 : FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  n.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _relativeTime(n.createdAt),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              if (!n.read) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}