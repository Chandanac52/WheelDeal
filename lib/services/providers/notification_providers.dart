import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_model.dart';
import '../repositories/vehicle_service.dart';

final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  return VehicleService.instance.getNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  return VehicleService.instance.getUnreadNotificationCount();
});