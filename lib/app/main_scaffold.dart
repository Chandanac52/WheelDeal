import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/chats_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/widgets/bottom_nav_bar.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/sell/sell_vehicle_screen.dart';
import '../services/providers/nav_providers.dart';
import '../services/providers/notification_providers.dart';
import '../services/socket/socket_service.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    SellVehicleScreen(),
    ChatsScreen(),
    ProfileScreen(),
  ];

  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    // Lives for the whole app session (this widget is never disposed while
    // signed in), so the Notifications list and its unread badge on Profile
    // stay live no matter which tab is currently open — not just while the
    // Notifications screen itself happens to be on screen.
    _notificationSub = SocketService.instance.notificationStream.listen((_) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(mainTabIndexProvider);
    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: BottomNavBar(
        currentIndex: index,
        onTap: (i) => ref.read(mainTabIndexProvider.notifier).state = i,
      ),
    );
  }
}