import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_model.dart';
import '../repositories/vehicle_service.dart';

final chatsProvider = FutureProvider<List<ChatSummary>>((ref) async {
  return VehicleService.instance.getChats();
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, chatId) async {
  return VehicleService.instance.getMessages(chatId);
});

final chatRefreshProvider = StateProvider<int>((ref) => 0);
