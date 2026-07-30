import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notification/notification_service.dart';

/// Explicit override always wins: `--dart-define=MEDTRACK_API_BASE_URL=...`
const _apiBaseUrlOverride = String.fromEnvironment('MEDTRACK_API_BASE_URL');

/// `localhost` means "this device" — on a real device or the Android
/// emulator that's the phone/emulator itself, not the machine running
/// `npm run start:dev`. The Android emulator maps the special address
/// `10.0.2.2` to the host machine's loopback, so that's the sane default
/// there; other platforms (iOS simulator, desktop, web) can reach the
/// host directly via `localhost`.
String _defaultApiBaseUrl() {
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000/v1';
  return 'http://localhost:3000/v1';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final apiBaseUrl =
      _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : _defaultApiBaseUrl();
  runApp(MedTrackApp(apiBaseUrl: apiBaseUrl));
}
