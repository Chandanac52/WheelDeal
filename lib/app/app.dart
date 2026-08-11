import 'package:flutter/material.dart';

import '../config/app_router.dart';
import '../core/theme/app_theme.dart';

class WheelDealApp extends StatelessWidget {
  const WheelDealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'WheelDeal',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}