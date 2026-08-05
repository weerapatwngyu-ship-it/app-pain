import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/notification/notification_service.dart';

/// Explicit override always wins: `--dart-define=MEDTRACK_API_BASE_URL=...`
const _apiBaseUrlOverride = String.fromEnvironment('MEDTRACK_API_BASE_URL');

/// Supabase project credentials, passed at build time:
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co
///   --dart-define=SUPABASE_ANON_KEY=<anon key>
/// The anon key is a public client key — it is safe to ship in the app, and
/// on its own grants nothing beyond what Supabase's own rules allow.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingSupabaseConfigApp());
    return;
  }

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  final apiBaseUrl =
      _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : _defaultApiBaseUrl();
  runApp(MedTrackApp(apiBaseUrl: apiBaseUrl));
}

/// Signing in is impossible without Supabase credentials, so say exactly
/// what is missing instead of failing later with an opaque auth error.
class _MissingSupabaseConfigApp extends StatelessWidget {
  const _MissingSupabaseConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ยังไม่ได้ตั้งค่า Supabase\n\n'
              'ต้องรันด้วยคำสั่งที่มี:\n'
              '--dart-define=SUPABASE_URL=...\n'
              '--dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
