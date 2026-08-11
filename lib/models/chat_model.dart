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
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      read: json['read'] as bool? ?? false,
      sender: json['sender'] != null
          ? ChatUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }
}
