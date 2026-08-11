import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_constants.dart';
import '../api/api_client.dart';

/// Wraps a single shared Socket.IO connection for real-time chat.
///
/// Usage: call [connect] once after login (e.g. in the auth provider or app
/// startup), then from a chat screen call [joinChat]/[leaveChat] and listen
/// to [messageStream], filtering by chatId.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();

  /// Emits `{chatId, message}` maps whenever the server pushes a new message.
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Emits `{chatId, message}` maps whenever a message is edited.
  Stream<Map<String, dynamic>> get messageUpdatedStream => _messageUpdatedController.stream;

  /// Emits `{chatId, messageId}` maps whenever a message is deleted.
  Stream<Map<String, dynamic>> get messageDeletedStream => _messageDeletedController.stream;

  /// Emits `{notification}` maps whenever a new notification is created for
  /// the current user (new message, price drop, callback request).
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (ApiConstants.useMockData) return; // no real backend to connect to
    final token = ApiClient.instance.token;
    if (token == null) return;

    // Already connected with a (possibly stale) token — reconnect cleanly.
    _socket?.dispose();

    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.on('newMessage', (data) {
      if (data is Map) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('messageUpdated', (data) {
      if (data is Map) {
        _messageUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('messageDeleted', (data) {
      if (data is Map) {
        _messageDeletedController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('newNotification', (data) {
      if (data is Map) {
        _notificationController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void joinChat(String chatId) => _socket?.emit('joinChat', chatId);
  void leaveChat(String chatId) => _socket?.emit('leaveChat', chatId);

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}