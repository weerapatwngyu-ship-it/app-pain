import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notification/notification_service.dart';

const _apiBaseUrl = String.fromEnvironment(
  'MEDTRACK_API_BASE_URL',
  defaultValue: 'http://localhost:3000/v1',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MedTrackApp(apiBaseUrl: _apiBaseUrl));
}
