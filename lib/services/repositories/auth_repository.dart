import '../../core/constants/api_constants.dart';
import '../../models/user_model.dart';
import '../api/api_client.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final _api = ApiClient.instance;

  /// Exchanges a verified Firebase phone-auth ID token for our own app JWT.
  Future<UserModel> loginWithFirebase({
    required String idToken,
    String? name,
  }) async {
    final data = await _api.post('/auth/firebase-login', body: {
      'idToken': idToken,
      'name': ?name,
    });
    await _api.setToken(data['token'] as String);
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel?> getCurrentUser() async {
    if (!_api.isAuthenticated) return null;
    try {
      final data = await _api.get('/auth/me');
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      await _api.setToken(null);
      return null;
    }
  }

  // FIX: no `phone` parameter, on purpose — it used to be here and get
  // sent straight through to PUT /auth/me. Phone is the verified sign-in
  // identity (proven via Firebase OTP at login), not a regular profile
  // field, so this layer shouldn't even offer the capability to send one.
  // The backend now refuses it either way (see auth.js), but the client
  // shouldn't hand out a method signature that implies this is a supported
  // thing to do.
  Future<UserModel> updateProfile({String? name, String? avatar}) async {
    final data = await _api.put('/auth/me', body: {
      'name': ?name,
      'avatar': ?avatar,
    });
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() => _api.setToken(null);

  bool get isLoggedIn => _api.isAuthenticated && !ApiConstants.useMockData;
}