import 'dart:io';

import '../../core/constants/api_constants.dart';
import '../../models/chat_model.dart';
import '../../models/dealer_model.dart';
import '../../models/notification_model.dart';
import '../../models/vehicle_model.dart';
import '../api/api_client.dart';
import '../providers/search_providers.dart';
import 'vehicle_repository.dart';

/// Result of createChat(): the chat's id, plus whether it was just created
/// (vs. an already-existing thread with that same person being reused).
/// Callers use `isNew` to decide whether a "Hi! I'm interested in..." draft
/// message belongs in the text box — only a genuinely first-ever chat with
/// that seller should get one, not every time chat is opened from a
/// vehicle page.
class ChatCreationResult {
  final String chatId;
  final bool isNew;

  const ChatCreationResult({required this.chatId, required this.isNew});
}

/// Unified data layer: uses live API when configured, otherwise mock data.
class VehicleService {
  VehicleService._();
  static final VehicleService instance = VehicleService._();

  final _api = ApiClient.instance;

  Future<List<VehicleModel>> getAll({
    String? query,
    String? category,
    bool? featured,
    SortOption? sort,
  }) async {
    if (ApiConstants.useMockData) {
      return _filterMock(query: query, category: category, featured: featured, sort: sort);
    }

    final queryParams = <String, String>{};
    if (query != null && query.isNotEmpty) queryParams['q'] = query;
    if (category != null && category != 'All') queryParams['category'] = category;
    if (featured == true) queryParams['featured'] = 'true';
    if (sort != null) {
      queryParams['sort'] = switch (sort) {
        SortOption.priceLowToHigh => 'price_asc',
        SortOption.priceHighToLow => 'price_desc',
        SortOption.yearNewest => 'year_desc',
        SortOption.relevance => 'relevance',
      };
    }

    final data = await _api.get('/vehicles', query: queryParams);
    final list = data['vehicles'] as List<dynamic>;
    return list.map((e) => VehicleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VehicleModel?> getById(String id) async {
    if (ApiConstants.useMockData) return VehicleRepository.byId(id);
    try {
      final data = await _api.get('/vehicles/$id');
      return VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<VehicleModel>> getFeatured() async {
    return getAll(featured: true);
  }

  Future<List<VehicleModel>> getMyListings() async {
    if (ApiConstants.useMockData) return [];
    final data = await _api.get('/vehicles/user/my-listings');
    final list = data['vehicles'] as List<dynamic>;
    return list.map((e) => VehicleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<VehicleModel> createListing(Map<String, dynamic> payload) async {
    final data = await _api.post('/vehicles', body: payload);
    return VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>);
  }

  Future<VehicleModel> updateListing(String id, Map<String, dynamic> payload) async {
    final data = await _api.put('/vehicles/$id', body: payload);
    return VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>);
  }

  /// Marks a listing the current user owns as SOLD (or relists it back to
  /// ACTIVE). This is what actually moves the seller's "N Sold" badge off
  /// zero — before this existed, nothing anywhere ever changed a vehicle's
  /// status to SOLD, so that count could never move no matter how many
  /// vehicles anyone sold through the app.
  Future<VehicleModel> updateVehicleStatus(String id, String status) async {
    if (ApiConstants.useMockData) {
      // No persistent mock backing store for status — mock mode is for UI
      // browsing, not a real seller flow, so this is a no-op there. Real
      // status changes only happen against the live backend.
      throw ApiException('Marking as sold requires the live backend, not mock mode.');
    }
    final data = await _api.put('/vehicles/$id/status', body: {'status': status});
    return VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>);
  }

  /// Permanently deletes a listing the current user owns. This is what
  /// backs the delete option in "My Listings" on the Profile screen — a
  /// distinct action from updateVehicleStatus(SOLD): marking sold keeps
  /// the vehicle around (it still counts toward "N Sold" and stays visible
  /// in "My Listings"), while this removes it outright. Once this returns,
  /// the vehicle is gone from the backend entirely, so it can never again
  /// appear in the public feed, search, favorites, or "My Listings" —
  /// callers should refresh/invalidate whatever listing providers they're
  /// showing right after this succeeds.
  Future<void> deleteListing(String id) async {
    if (ApiConstants.useMockData) {
      // Same reasoning as updateVehicleStatus: mock mode has no real
      // backing store to delete from, so this only works against the live
      // backend.
      throw ApiException('Deleting a listing requires the live backend, not mock mode.');
    }
    await _api.delete('/vehicles/$id');
  }

  /// Uploads photos and returns their public URLs. In demo/mock mode,
  /// returns bundled placeholder assets instead (no real upload happens).
  Future<List<String>> uploadImages(List<File> files) async {
    if (ApiConstants.useMockData) {
      return List.generate(files.length, (_) => 'assets/images/cars/placeholder.png');
    }
    return _api.uploadImages(files);
  }

  Future<void> requestCallback(String vehicleId, {String? phone}) async {
    if (ApiConstants.useMockData) return;
    await _api.post('/vehicles/$vehicleId/callback', body: {
      'phone': ?phone,
    });
  }

  Future<List<DealerModel>> getDealers() async {
    if (ApiConstants.useMockData) return VehicleRepository.mockDealers;
    final data = await _api.get('/dealers');
    final list = data['dealers'] as List<dynamic>;
    return list.map((e) => DealerModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetches one dealer's full profile, including their active listings
  /// (unlike getDealers(), which only returns the summary fields shown on
  /// the Home "Popular Dealers" cards).
  Future<DealerModel?> getDealerById(String id) async {
    if (ApiConstants.useMockData) {
      try {
        return VehicleRepository.mockDealers.firstWhere((d) => d.id == id);
      } catch (_) {
        return null;
      }
    }
    try {
      final data = await _api.get('/dealers/$id');
      return DealerModel.fromJson(data['dealer'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Every review a dealer has actually received, newest first — powers
  /// the review list on the Dealer Profile screen.
  Future<List<DealerReviewModel>> getDealerReviews(String dealerId) async {
    if (ApiConstants.useMockData) return [];
    final data = await _api.get('/dealers/$dealerId/reviews');
    final list = data['reviews'] as List<dynamic>;
    return list.map((e) => DealerReviewModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Submits (or updates, if the signed-in buyer already reviewed this
  /// dealer) a 1–5 star rating with an optional comment. This is the only
  /// thing that actually feeds Dealer.rating — there's no other path that
  /// changes it, by design (see the Review model comment in
  /// schema.prisma): a dealer's rating is real user input, never a stored
  /// default or something a listing edit can touch.
  Future<void> submitDealerReview(String dealerId, {required int rating, String? comment}) async {
    if (ApiConstants.useMockData) {
      throw ApiException('Reviews require the live backend, not mock mode.');
    }
    await _api.post('/dealers/$dealerId/reviews', body: {
      'rating': rating,
      'comment': ?comment,
    });
  }

  Future<List<String>> getFavoriteIds() async {
    if (ApiConstants.useMockData) return [];
    final data = await _api.get('/favorites');
    return (data['favorites'] as List<dynamic>).map((e) => e as String).toList();
  }

  Future<void> addFavorite(String vehicleId) async {
    if (ApiConstants.useMockData) return;
    await _api.post('/favorites/$vehicleId');
  }

  Future<void> removeFavorite(String vehicleId) async {
    if (ApiConstants.useMockData) return;
    await _api.delete('/favorites/$vehicleId');
  }

  Future<List<ChatSummary>> getChats() async {
    if (ApiConstants.useMockData) return VehicleRepository.mockChats;
    final data = await _api.get('/chats');
    final list = data['chats'] as List<dynamic>;
    return list.map((e) => ChatSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessage>> getMessages(String chatId) async {
    if (ApiConstants.useMockData) {
      return VehicleRepository.mockMessages[chatId] ?? [];
    }
    final data = await _api.get('/chats/$chatId/messages');
    final list = data['messages'] as List<dynamic>;
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates a chat with [recipientId], or reuses the existing one if these
  /// two people already have a thread together. Check `.isNew` on the
  /// result before deciding to pre-fill a draft opening message — see
  /// ChatCreationResult above.
  Future<ChatCreationResult> createChat(String recipientId, {String? vehicleId}) async {
    if (ApiConstants.useMockData) {
      return const ChatCreationResult(chatId: 'mock-chat-1', isNew: true);
    }
    final data = await _api.post('/chats', body: {
      'recipientId': recipientId,
      'vehicleId': ?vehicleId,
    });
    return ChatCreationResult(
      chatId: data['chatId'] as String,
      // Default true (rather than false) if the backend response is ever
      // missing this field for some reason — worst case a stale server
      // shows one unnecessary draft message rather than silently never
      // showing one on a real first-time chat.
      isNew: data['isNew'] as bool? ?? true,
    );
  }

  Future<ChatMessage> sendMessage(String chatId, String content) async {
    if (ApiConstants.useMockData) {
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        senderId: 'me',
        createdAt: DateTime.now(),
      );
      VehicleRepository.mockMessages.putIfAbsent(chatId, () => []).add(message);
      return message;
    }
    final data = await _api.post('/chats/$chatId/messages', body: {'content': content});
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  static const _editWindow = Duration(minutes: 15);

  Future<ChatMessage> editMessage(String chatId, String messageId, String content) async {
    if (ApiConstants.useMockData) {
      final list = VehicleRepository.mockMessages[chatId];
      final idx = list?.indexWhere((m) => m.id == messageId) ?? -1;
      if (list == null || idx == -1) {
        throw ApiException('Message not found');
      }
      if (list[idx].deleted) {
        throw ApiException('Cannot edit a deleted message');
      }
      if (DateTime.now().difference(list[idx].createdAt) > _editWindow) {
        throw ApiException('This message is too old to edit');
      }
      final updated = list[idx].copyWith(content: content, edited: true);
      list[idx] = updated;
      return updated;
    }
    final data = await _api.put('/chats/$chatId/messages/$messageId', body: {'content': content});
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    if (ApiConstants.useMockData) {
      final list = VehicleRepository.mockMessages[chatId];
      final idx = list?.indexWhere((m) => m.id == messageId) ?? -1;
      if (list == null || idx == -1) {
        throw ApiException('Message not found');
      }
      if (list[idx].deleted) {
        throw ApiException('Message is already deleted');
      }
      if (DateTime.now().difference(list[idx].createdAt) > _editWindow) {
        throw ApiException('This message is too old to delete');
      }
      list[idx] = list[idx].copyWith(content: '', deleted: true);
      return;
    }
    await _api.delete('/chats/$chatId/messages/$messageId');
  }

  /// Marks every message from the other participant in [chatId] as read.
  /// Call this when the chat thread is actually opened — this is what
  /// clears the unread dot on the Messages list.
  Future<void> markChatRead(String chatId) async {
    if (ApiConstants.useMockData) {
      final list = VehicleRepository.mockMessages[chatId];
      if (list == null) return;
      for (var i = 0; i < list.length; i++) {
        if (list[i].senderId != 'me' && !list[i].read) {
          list[i] = list[i].copyWith(read: true);
        }
      }
      return;
    }
    await _api.put('/chats/$chatId/read');
  }

  List<VehicleModel> _filterMock({
    String? query,
    String? category,
    bool? featured,
    SortOption? sort,
  }) {
    var results = VehicleRepository.all.where((v) {
      final q = query?.trim().toLowerCase() ?? '';
      final matchesQuery = q.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.dealerName.toLowerCase().contains(q) ||
          v.location.toLowerCase().contains(q) ||
          v.category.toLowerCase().contains(q);
      final matchesCategory = category == null || category == 'All' || v.category == category;
      final matchesFeatured = featured != true || v.isFeatured;
      return matchesQuery && matchesCategory && matchesFeatured;
    }).toList();

    if (sort != null) {
      int priceValue(VehicleModel v) {
        final digits = v.price.replaceAll(RegExp(r'[^0-9.]'), '');
        final base = double.tryParse(digits) ?? 0;
        if (v.price.contains('L')) return (base * 100000).round();
        if (v.price.contains('K')) return (base * 1000).round();
        return base.round();
      }

      switch (sort) {
        case SortOption.priceLowToHigh:
          results.sort((a, b) => priceValue(a).compareTo(priceValue(b)));
        case SortOption.priceHighToLow:
          results.sort((a, b) => priceValue(b).compareTo(priceValue(a)));
        case SortOption.yearNewest:
          results.sort((a, b) => b.year.compareTo(a.year));
        case SortOption.relevance:
          break;
      }
    }

    return results;
  }

  Future<List<NotificationModel>> getNotifications() async {
    if (ApiConstants.useMockData) {
      return List<NotificationModel>.from(VehicleRepository.mockNotifications)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final data = await _api.get('/notifications');
    return (data['notifications'] as List<dynamic>)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadNotificationCount() async {
    if (ApiConstants.useMockData) {
      return VehicleRepository.mockNotifications.where((n) => !n.read).length;
    }
    final data = await _api.get('/notifications/unread-count');
    return data['count'] as int? ?? 0;
  }

  Future<void> markNotificationRead(String id) async {
    if (ApiConstants.useMockData) {
      final list = VehicleRepository.mockNotifications;
      final idx = list.indexWhere((n) => n.id == id);
      if (idx != -1) list[idx] = list[idx].copyWith(read: true);
      return;
    }
    await _api.put('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    if (ApiConstants.useMockData) {
      final list = VehicleRepository.mockNotifications;
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(read: true);
      }
      return;
    }
    await _api.put('/notifications/read-all');
  }
}