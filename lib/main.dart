import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Requires android/app/google-services.json (and ios/Runner/GoogleService-Info.plist
  // for iOS) from your own Firebase project — see DEPLOYMENT_GUIDE.md "Phone OTP Login".
  // Wrapped in try/catch so the rest of the app still works before you've set
  // that up; only the phone-login screen needs Firebase to actually be configured.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase not configured yet — phone OTP login will be unavailable: $e');
  }

  runApp(
    const ProviderScope(
      child: WheelDealApp(),
    ),
  );
}