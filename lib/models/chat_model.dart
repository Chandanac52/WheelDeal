class ChatSummary {
  final String id;
  final ChatUser? otherUser;
  final ChatMessage? lastMessage;
  final DateTime? updatedAt;

  const ChatSummary({
    required this.id,
    this.otherUser,
    this.lastMessage,
    this.updatedAt,
  });

  /// True when the most recent message was sent BY the other person and
  /// hasn't been marked read yet. This is what powers the unread dot on
  /// the chats list. [myUserId] must be passed in from the caller (the
  /// model itself has no notion of "who is currently logged in").
  bool isUnreadFor(String? myUserId) {
    final last = lastMessage;
    if (last == null || myUserId == null) return false;
    return last.senderId != myUserId && !last.read;
  }

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    return ChatSummary(
      id: json['id'] as String,
      otherUser: json['otherUser'] != null
          ? ChatUser.fromJson(json['otherUser'] as Map<String, dynamic>)
          : null,
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      // FIX: was DateTime.tryParse(...) with no .toLocal() — same root
      // cause as ChatMessage.createdAt below. Wasn't yet visibly wrong
      // anywhere (nothing currently formats updatedAt as a clock time —
      // it's only ever used to sort the chats list by recency, which
      // works correctly regardless of timezone since comparing two
      // instants doesn't care how they're displayed), but leaving it
      // UTC-flagged here was a bug waiting for the first screen that
      // does show it as a time. Converting once, at parse time, means
      // nothing downstream has to remember to do it.
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)?.toLocal()
          : null,
    );
  }
}

class ChatUser {
  final String id;
  final String name;
  final String? avatar;

  const ChatUser({required this.id, required this.name, this.avatar});

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;
  final bool edited;
  final bool deleted;
  final bool read;
  final ChatUser? sender;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
    this.edited = false,
    this.deleted = false,
    this.read = false,
    this.sender,
  });

  ChatMessage copyWith({String? content, bool? edited, bool? deleted, bool? read}) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      senderId: senderId,
      createdAt: createdAt,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      read: read ?? this.read,
      sender: sender,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      content: json['content'] as String,
      senderId: json['senderId'] as String,
      // FIX: this used to be plain DateTime.parse(...) — the backend
      // (Prisma DateTime -> Express res.json()) serializes createdAt as
      // an ISO string with a 'Z' suffix, i.e. genuinely UTC, and
      // DateTime.parse() correctly honors that by returning a
      // UTC-flagged DateTime. Nothing anywhere then converted it back to
      // the device's local time before formatting it as a clock time —
      // chat_detail_screen.dart's bubble does
      // DateFormat('h:mm a').format(message.createdAt), and
      // DateFormat.format() renders whatever hour/minute the DateTime
      // object already carries, UTC or not, with no timezone conversion
      // of its own. The result was every message bubble showing raw UTC
      // time as if it were local (a ~5.5 hour gap for IST — exactly what
      // was observed). .toLocal() converts once, right here at parse
      // time, so every current and future place that reads
      // message.createdAt automatically gets correct local time; it's
      // also safe to call even if a future backend ever sent a
      // timezone-less string instead (Dart already treats those as
      // local on parse, and .toLocal() on an already-local DateTime is
      // a no-op).
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      read: json['read'] as bool? ?? false,
      sender: json['sender'] != null
          ? ChatUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }
}