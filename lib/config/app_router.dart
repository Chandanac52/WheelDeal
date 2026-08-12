import 'package:go_router/go_router.dart';

import '../app/main_scaffold.dart';
import '../features/auth/phone_login_screen.dart';
import '../features/chat/chat_detail_screen.dart';
import '../features/dealer/all_dealers_screen.dart';
import '../features/dealer/dealer_profile_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/sell/sell_vehicle_screen.dart';
import '../features/support/help_support_screen.dart';
import '../features/vehicle/screens/vehicle_details_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: '/vehicle/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VehicleDetailsScreen(vehicleId: id);
        },
      ),
      // There is no separate "edit vehicle" screen — creating a new
      // listing and editing an existing one are the same form
      // (SellVehicleScreen), just told which mode to run in via
      // editVehicleId. Passing an id here makes it load that vehicle and
      // prefill the form (then call VehicleService.updateListing on save);
      // the '/sell' entry point elsewhere in the app calls this same
      // widget with no editVehicleId, so it starts blank and calls
      // createListing instead. Worth knowing before searching the
      // codebase for a file that isn't there — see sell_vehicle_screen.dart.
      GoRoute(
        path: '/edit-vehicle/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SellVehicleScreen(editVehicleId: id);
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;

          // Accepts two shapes so nothing else that already navigates here
          // has to change: a plain String (existing behaviour — just the
          // other user's name, e.g. from the chats list) or the newer
          // ChatOpenArgs (name + a draft message to pre-fill, used when
          // opening a chat from a vehicle page).
          String? name;
          String? draft;
          if (extra is ChatOpenArgs) {
            name = extra.otherUserName;
            draft = extra.draftMessage;
          } else if (extra is String) {
            name = extra;
          }

          return ChatDetailScreen(chatId: id, otherUserName: name, draftMessage: draft);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/help-support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/dealers',
        builder: (context, state) => const AllDealersScreen(),
      ),
      GoRoute(
        path: '/dealer/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DealerProfileScreen(dealerId: id);
        },
      ),
    ],
  );
}