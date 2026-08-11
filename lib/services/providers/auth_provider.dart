import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../models/user_model.dart';
import '../api/api_client.dart';
import '../repositories/auth_repository.dart';
import '../socket/socket_service.dart';
import 'favorites_provider.dart';
import 'notification_providers.dart';
import 'vehicle_providers.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated =>
      user != null || (ApiConstants.useMockData && _mockLoggedIn);

  static bool _mockLoggedIn = false;

  AuthState copyWith({UserModel? user, bool? isLoading, String? error, bool clearError = false}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  final Ref _ref;

  // myListingsProvider, favoritesProvider, notificationsProvider, and
  // unreadNotificationCountProvider all fetch data scoped to whichever user
  // is currently logged in, but none of them are `.autoDispose` — Riverpod
  // caches each result and keeps serving it from memory forever until
  // something invalidates it. Without this, User A's data (listings,
  // favourites, AND notifications) would still be showing after User B logs
  // in on the same app session, because nothing ever told those providers
  // the logged-in user had changed.
  //
  // notificationsProvider/unreadNotificationCountProvider were missing from
  // this list — that was the exact cause of Rajesh seeing "You're all
  // caught up" right after logging in, even though a real notification had
  // just been created for him server-side: the screen was still showing
  // whichever account's (possibly empty) notification state was cached from
  // before the switch, never having been told to refetch.
  void _invalidateUserScopedProviders() {
    _ref.invalidate(myListingsProvider);
    _ref.invalidate(favoritesProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> _init() async {
    await ApiClient.instance.init();
    if (ApiConstants.useMockData) {
      if (AuthState._mockLoggedIn) {
        state = state.copyWith(
          user: const UserModel(
            id: 'mock-user',
            email: 'demo@wheeldeal.com',
            name: 'Demo User',
            phone: '+91 98765 43210',
            avatar: 'assets/images/avatars/profile.png',
          ),
        );
      }
      return;
    }
    state = state.copyWith(isLoading: true);
    final user = await AuthRepository.instance.getCurrentUser();
    state = AuthState(user: user, isLoading: false);
    if (user != null) SocketService.instance.connect();
  }

  /// Called by the OTP screen once Firebase confirms the SMS code. Trades
  /// the resulting Firebase ID token for our own app JWT via the backend.
  Future<bool> loginWithFirebasePhone(String idToken) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (ApiConstants.useMockData) {
        await Future.delayed(const Duration(milliseconds: 400));
        AuthState._mockLoggedIn = true;
        state = const AuthState(
          user: UserModel(
            id: 'mock-user',
            name: 'Phone User',
            phone: '+91 98765 43210',
            avatar: 'assets/images/avatars/profile.png',
          ),
        );
        _invalidateUserScopedProviders();
        return true;
      }
      final user = await AuthRepository.instance.loginWithFirebase(idToken: idToken);
      state = AuthState(user: user);
      SocketService.instance.connect();
      _invalidateUserScopedProviders();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    if (!ApiConstants.useMockData) {
      await AuthRepository.instance.logout();
    } else {
      AuthState._mockLoggedIn = false;
    }
    SocketService.instance.disconnect();
    state = const AuthState();
    _invalidateUserScopedProviders();
  }

  // FIX: no `phone` parameter, on purpose — it used to be here and get
  // passed straight through to AuthRepository.instance.updateProfile(...),
  // which no longer accepts one (see auth_repository.dart). That mismatch
  // is exactly the "named parameter 'phone' isn't defined" error. Phone is
  // the verified sign-in identity (proven via Firebase OTP at login), not
  // a regular profile field — every layer (this one, the repository, and
  // the backend route) needs to agree it's not editable here, or a
  // signature like this drifting back out of sync with the others is
  // exactly how this bug came back.
  Future<void> updateProfile({String? name, String? avatar}) async {
    if (ApiConstants.useMockData && state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(name: name, avatar: avatar),
      );
      return;
    }
    final user = await AuthRepository.instance.updateProfile(name: name, avatar: avatar);
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);