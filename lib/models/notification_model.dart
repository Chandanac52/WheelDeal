class NotificationModel {
  final String id;
  final String type; // 'message' | 'price_drop' | 'callback' | 'system'
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? relatedVehicleId;
  final String? relatedChatId;
  // The number to call back on a 'callback' notification. Separate from
  // the requester's account phone since they can supply a different
  // reachable number when requesting the callback (see the "Request
  // Callback" sheet — it's an optional field there).
  final String? relatedPhone;
  // How many times this notification has fired without being replaced by
  // a new row — currently only meaningful for 'callback' notifications,
  // where it counts repeat requests from the SAME buyer about the SAME
  // vehicle (see vehicles.js). Always 1 for a notification that's only
  // happened once. The Notifications screen shows this as "Callback
  // requested (N)" once it passes 1, so the seller can see at a glance how
  // many times someone's tried to reach them, instead of the list just
  // filling up with near-duplicate rows for the same person.
  final int count;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.relatedVehicleId,
    this.relatedChatId,
    this.relatedPhone,
    this.count = 1,
  });

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      relatedVehicleId: relatedVehicleId,
      relatedChatId: relatedChatId,
      relatedPhone: relatedPhone,
      count: count,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String,
      body: json['body'] as String,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      relatedVehicleId: json['relatedVehicleId'] as String?,
      relatedChatId: json['relatedChatId'] as String?,
      relatedPhone: json['relatedPhone'] as String?,
      count: json['count'] as int? ?? 1,
    );
  }
}