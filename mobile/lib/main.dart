import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/notification/notification_service.dart';
import 'features/reminders/data/reminder_watch_service.dart';

/// Supabase project credentials, passed at build time. Easiest route is to
/// copy dart_defines.example.json to dart_defines.json, fill it in, and:
///   flutter build apk --release --dart-define-from-file=dart_defines.json
/// Or pass them one at a time:
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co
///   --dart-define=SUPABASE_ANON_KEY=<anon key>
/// The anon key is a public client key — it is safe to ship in the app, and
/// on its own grants nothing beyond what Supabase's own rules allow.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// The OAuth 2.0 "Web application" client ID from Google Cloud Console — not
/// a secret (it appears in every Google Sign-In request the app makes) but
/// still build-time config, since which Google Cloud project the app talks
/// to isn't something to hardcode. Left empty, sign-in still works with
/// email/password; only the Google button stays hidden.
///   --dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>.apps.googleusercontent.com
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never let notification setup stop the app from starting. It already did
  // once: an icon name that failed to resolve threw here, main() ended before
  // runApp(), and the app sat on its splash screen forever. Reminders are
  // important, but not more important than being able to open the app and
  // read a prescription.
  try {
    await NotificationService.instance.init();
  } catch (error, stack) {
    debugPrint('NotificationService.init failed: $error\n$stack');
  }

  // Bring the reminder service back up. It survives the app being closed but
  // not the app being force stopped, and this is the moment it can be started
  // again. Wrapped for the same reason as the line above.
  try {
    await ReminderWatchService.start();
  } catch (error, stack) {
    debugPrint('ReminderWatchService.start failed: $error\n$stack');
  }

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingSupabaseConfigApp());
    return;
  }

  // Supabase is the whole backend: auth, database and file storage. There
  // is no server of this app's own to point at.
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  runApp(
    MediGoApp(
      googleWebClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
    ),
  );
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
              'แอปถูก build โดยไม่ได้ใส่ค่าเชื่อมต่อฐานข้อมูล\n\n'
              'วิธีแก้ — ที่โฟลเดอร์ mobile:\n'
              '1. คัดลอก dart_defines.example.json\n'
              '   เป็น dart_defines.json\n'
              '2. ใส่ URL และ anon key ของโปรเจกต์\n'
              '3. flutter build apk --release\n'
              '   --dart-define-from-file=dart_defines.json',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}
