import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/providers/auth_provider.dart';
import '../../services/providers/chat_providers.dart';
import '../../services/socket/socket_service.dart';
import '../../widgets/app_image.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  @override
  void initState() {
    super.initState();
    _socketSub = SocketService.instance.messageStream.listen((_) {
      ref.invalidate(chatsProvider);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(chatsProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!auth.isAuthenticated) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Sign in to view your chats'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final chats = ref.watch(chatsProvider);
    final myId = auth.user?.id;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Messages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: chats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text(
                        'No conversations yet.\nContact a seller from a listing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  // No Divider between rows anymore — WhatsApp/Telegram-style
                  // lists don't use hard separator lines at all; the row
                  // itself (rounded, tinted while unread, breathing room
                  // above/below) is what visually separates one
                  // conversation from the next.
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final chat = list[index];
                        final other = chat.otherUser;
                        final last = chat.lastMessage;
                        final time = last != null
                            ? DateFormat('MMM d, h:mm a').format(last.createdAt)
                            : '';
                        final isUnread = chat.isUnreadFor(myId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: isUnread
                                ? AppColors.primaryLight.withValues(alpha: 0.6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push('/chat/${chat.id}', extra: other?.name),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(26),
                                          child: AppImage(
                                            source: other?.avatar ?? 'assets/images/avatars/profile.png',
                                            width: 52,
                                            height: 52,
                                          ),
                                        ),
                                        // The actual unread dot — was never
                                        // wired to real data before, since
                                        // ChatMessage had no `read` field
                                        // reaching the client at all.
                                        if (isUnread)
                                          Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            other?.name ?? 'Unknown',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            last?.content ?? 'Start a conversation',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                              color: isUnread
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isUnread ? AppColors.primary : AppColors.textSecondary,
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}