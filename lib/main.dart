import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'theme/app_tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dark camera UI: light status-bar icons over the black preview.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppTokens.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GPSCameraApp());
}
