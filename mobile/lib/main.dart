import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // Debug-only check on the credentials, because "Invalid API key" arrives
  // at the sign-in screen with no way to tell which of several causes it is:
  // a truncated key, a key for another project, or a key the project has
  // since disabled. Prints what was actually compiled in, then asks Supabase
  // directly and reports the verdict.
  if (kDebugMode) await _reportSupabaseConfig();

  // Supabase is the whole backend: auth, database and file storage. There
  // is no server of this app's own to point at.
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  runApp(
    MediGoApp(
      googleWebClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
    ),
  );
}

/// The configured URL without a trailing slash, so joining a path to it
/// cannot produce a double slash the server would 404 on.
String get _trimmedSupabaseUrl {
  var url = _supabaseUrl.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// Prints what the build was given and what Supabase makes of it.
///
/// Debug builds only. Reveals nothing the app does not already ship: the anon
/// key is a public client key, and the claims printed here are the key's own
/// unencrypted middle segment.
Future<void> _reportSupabaseConfig() async {
  void line(String text) => debugPrint('[supabase-check] $text');

  line('URL = $_supabaseUrl');
  line('key length = ${_supabaseAnonKey.length}, dots = '
      '${_supabaseAnonKey.split('.').length - 1}');
  line('key starts = ${_supabaseAnonKey.substring(0, _supabaseAnonKey.length.clamp(0, 12))}');
  line('GOOGLE_WEB_CLIENT_ID = '
      '${_googleWebClientId.isEmpty ? "(ว่าง — ปุ่ม Google จะไม่ขึ้น)" : _googleWebClientId}');

  // A legacy key carries its project ref and role in the clear; a new-style
  // publishable key carries neither, so say which kind arrived.
  if (_supabaseAnonKey.startsWith('sb_publishable_')) {
    line('kind = publishable key (แบบใหม่)');
  } else if (_supabaseAnonKey.startsWith('sb_secret_')) {
    line('kind = SECRET KEY — ห้ามใช้ในแอป ไปเอา publishable key มาแทน');
  } else {
    final parts = _supabaseAnonKey.split('.');
    if (parts.length == 3) {
      try {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        ) as Map<String, dynamic>;
        line('kind = legacy JWT, ref = ${payload["ref"]}, role = ${payload["role"]}');
        final refInUrl = Uri.parse(_supabaseUrl).host.split('.').first;
        if (payload['ref'] != refInUrl) {
          line('!! ref ไม่ตรงกับ URL ($refInUrl) — key มาจากคนละโปรเจกต์');
        }
      } catch (e) {
        line('!! ถอด JWT ไม่ได้: $e');
      }
    } else {
      line('!! รูปแบบ key ไม่ถูก — ควรมี 3 ท่อนคั่นด้วยจุด');
    }
  }

  try {
    final response = await http.get(
      Uri.parse('$_trimmedSupabaseUrl/auth/v1/settings'),
      headers: {'apikey': _supabaseAnonKey},
    );
    line('GET /auth/v1/settings -> HTTP ${response.statusCode}');
    if (response.statusCode == 200) {
      line('ผลลัพธ์: key ใช้งานได้ ✓');
    } else {
      line('ผลลัพธ์: Supabase ปฏิเสธ -> ${response.body}');
      line('ถ้าเป็น Invalid API key ทั้งที่ ref/role ถูก แปลว่าโปรเจกต์ปิด '
          'legacy key ไว้ ให้ไปเอา publishable key มาใส่แทน');
    }
  } catch (e) {
    line('!! ต่อ Supabase ไม่ได้เลย (เน็ต/DNS/ไฟร์วอลล์): $e');
  }
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
