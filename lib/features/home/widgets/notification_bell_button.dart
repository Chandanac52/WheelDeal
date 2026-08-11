import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/providers/notification_providers.dart';

/// Self-contained: watches the real unread count and handles its own
/// navigation, so every call site (just `const NotificationBellButton()` in
/// home_screen.dart) gets correct live behavior with zero wiring needed at
/// the call site. Previously `hasUnread` defaulted to `true` and nothing
/// ever passed a real value in, so the red dot was permanently on
/// regardless of actual notifications; `onTap` was never supplied either,
/// so tapping it did nothing at all.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final hasUnread = unreadCount.maybeWhen(data: (count) => count > 0, orElse: () => false);

    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          if (hasUnread)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
