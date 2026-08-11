import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/chat_model.dart';
import '../../services/providers/auth_provider.dart';
import '../../services/providers/chat_providers.dart';
import '../../services/providers/notification_providers.dart';
import '../../services/repositories/vehicle_service.dart';
import '../../services/socket/socket_service.dart';

/// Passed as `GoRouterState.extra` when opening a chat so the target screen
/// gets more than just a name — currently used to carry a draft message
/// (see vehicle_details_screen.dart / contact_button.dart) that's
/// pre-filled into the text box but never sent automatically. Kept
/// separate from a plain String so existing call sites that only pass the
/// other user's name (e.g. the chats list) don't need to change at all —
/// app_router.dart accepts either shape.
class ChatOpenArgs {
  final String? otherUserName;
  final String? draftMessage;

  const ChatOpenArgs({this.otherUserName, this.draftMessage});
}

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? otherUserName;
  final String? draftMessage;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.otherUserName,
    this.draftMessage,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;

  @override
  void initState() {
    super.initState();

    // Pre-fills the text box with a suggested opener (e.g. "Hi! I'm
    // interested in your Tata Nexon...") when arriving from a vehicle
    // page — the person can read it, edit it, or clear it, but it is
    // NEVER sent automatically. This only ever touches the local text
    // field; nothing is sent to the server until they tap send themselves.
    if (widget.draftMessage != null && widget.draftMessage!.isNotEmpty) {
      _controller.text = widget.draftMessage!;
    }

    // Real-time: join this chat's room so the server pushes new messages to
    // us instantly over the socket, from either side of the conversation.
    SocketService.instance.joinChat(widget.chatId);

    // This is the other half of the unread-dot feature: the backend only
    // clears `read` on messages when explicitly told to, and this is where
    // that "told to" happens — the moment the person actually opens the
    // thread. Without this call, unread would never clear no matter how
    // long the chat stays open. The backend also clears this chat's linked
    // notification as part of the same call now, so all three places that
    // show unread state — the per-chat dot here, the "N new" badge on
    // Profile, and the red dot on the Home bell — go back in sync the
    // moment you actually read the conversation, not just the one you
    // happened to open it from.
    _markReadEverywhere();

    _socketSub = SocketService.instance.messageStream.listen((event) {
      if (event['chatId'] == widget.chatId) {
        ref.invalidate(chatMessagesProvider(widget.chatId));
        _scrollToBottom();
        // A new message arrived while the thread is already open — mark it
        // read immediately too, rather than waiting for the next time this
        // screen is opened from scratch.
        _markReadEverywhere();
      }
    });
    // Same chat's other participant may edit or delete a message while we
    // have the thread open — refresh so we see it immediately either way.
    _updatedSub = SocketService.instance.messageUpdatedStream.listen((event) {
      if (event['chatId'] == widget.chatId) {
        ref.invalidate(chatMessagesProvider(widget.chatId));
      }
    });
    _deletedSub = SocketService.instance.messageDeletedStream.listen((event) {
      if (event['chatId'] == widget.chatId) {
        ref.invalidate(chatMessagesProvider(widget.chatId));
      }
    });

    // Fallback poll — much slower than before, since the socket now does the
    // real-time work. This just covers the socket being mid-reconnect.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(chatMessagesProvider(widget.chatId));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Marks this chat read on the server (which also clears its linked
  // notification server-side now — see chats.js PUT /:chatId/read), then
  // refreshes every local provider that displays unread state anywhere in
  // the app, so the chat-list dot, the Profile "N new" badge, and the Home
  // bell's red dot all clear together instead of only whichever screen
  // triggered the read.
  void _markReadEverywhere() {
    VehicleService.instance.markChatRead(widget.chatId).then((_) {
      if (!mounted) return;
      ref.invalidate(chatsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    });
  }

  @override
  void dispose() {
    SocketService.instance.leaveChat(widget.chatId);
    _socketSub?.cancel();
    _updatedSub?.cancel();
    _deletedSub?.cancel();
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await VehicleService.instance.sendMessage(widget.chatId, text);
      ref.invalidate(chatMessagesProvider(widget.chatId));
      ref.invalidate(chatsProvider);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _editWindow = Duration(minutes: 15);
  static const _deleteWindow = Duration(minutes: 15);

  void _showMessageOptions(ChatMessage message) {
    final age = DateTime.now().difference(message.createdAt);
    final canStillEdit = age <= _editWindow;
    final canStillDelete = age <= _deleteWindow;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canStillEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editMessage(message);
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.edit_off_outlined, color: AppColors.textSecondary),
                title: Text(
                  'Too old to edit',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                subtitle: Text('Messages can only be edited within 15 minutes of sending'),
              ),
            if (canStillDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete message', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(message);
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.textSecondary),
                title: Text(
                  'Too old to delete',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                subtitle: Text('Messages can only be deleted within 15 minutes of sending'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final editController = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = editController.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newContent == null || newContent == message.content || !mounted) return;
    try {
      await VehicleService.instance.editMessage(widget.chatId, message.id, newContent);
      ref.invalidate(chatMessagesProvider(widget.chatId));
      ref.invalidate(chatsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be removed for everyone in this chat.'),
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

    if (confirmed != true || !mounted) return;
    try {
      await VehicleService.instance.deleteMessage(widget.chatId, message.id);
      ref.invalidate(chatMessagesProvider(widget.chatId));
      ref.invalidate(chatsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final auth = ref.watch(authProvider);
    final myId = auth.user?.id ?? 'me';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName ?? 'Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet — say hello!',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final message = list[i];
                        final isMe = message.senderId == myId || message.senderId == 'me';
                        return _Bubble(
                          message: message,
                          isMe: isMe,
                          onLongPress: (isMe && !message.deleted)
                              ? () => _showMessageOptions(message)
                              : null,
                        );
                      },
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onLongPress;

  const _Bubble({required this.message, required this.isMe, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : AppColors.inputBackground,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.deleted ? 'This message was deleted' : message.content,
                style: TextStyle(
                  color: message.deleted
                      ? (isMe ? Colors.white70 : AppColors.textSecondary)
                      : (isMe ? Colors.white : AppColors.textPrimary),
                  fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.deleted && message.edited) ...[
                    Text(
                      'edited · ',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  Text(
                    DateFormat('h:mm a').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}