/// API configuration for WheelDeal.
///
/// Before deploying:
/// 1. Deploy the backend (see DEPLOYMENT_GUIDE.md)
/// 2. Replace [baseUrl] with your production API URL
/// 3. Set [useMockData] to false
class ApiConstants {
  ApiConstants._();

  /// Local dev: Android emulator uses 10.0.2.2, iOS simulator uses localhost.
  /// Physical device: use your PC's LAN IP, e.g. http://192.168.1.5:3000
  static const String baseUrl = 'http://192.168.0.112:3000';

  /// When true, the app uses built-in mock data (works offline, no backend needed).
  /// Set to false once your backend is deployed and reachable.
  static const bool useMockData = false;

  static const Duration requestTimeout = Duration(seconds: 15);

  static String get apiBase => '$baseUrl/api';
}
