import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'theme/app_tokens.dart';

/// GPS Camera MVP (spec §1): a single full-screen camera. No menus, no
/// onboarding, no dashboard — minimal iPhone-style camera UI.
class GPSCameraApp extends StatelessWidget {
  const GPSCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Camera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTokens.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTokens.white,
          brightness: Brightness.dark,
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
