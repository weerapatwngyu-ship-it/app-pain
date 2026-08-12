import 'dart:convert';

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

  // Ask Supabase whether it accepts these credentials before showing a
  // sign-in screen that cannot work without them.
  //
  // "Invalid API key" used to surface as four red words under the password
  // field, identical whether the key was truncated on copy, belonged to
  // another project, was a secret key by mistake, or had been disabled — each
  // needing a different fix. A refusal now stops here and shows what was
  // compiled in alongside the server's own answer.
  final report = await _checkCredentials();
  for (final line in report.lines) {
    debugPrint('[supabase-check] $line');
  }
  if (report.refused) {
    runApp(_RejectedConfigApp(report));
    return;
  }

  // Supabase is the whole backend: auth, database and file storage. There
  // is no server of this app's own to point at.
  //
  // Trimmed because these arrive from a JSON file a person edits, and a
  // stray space inside the quotes is invisible there but makes every request
  // fail with the same unhelpful rejection.
  await Supabase.initialize(
    url: _trimmedSupabaseUrl,
    anonKey: _supabaseAnonKey.trim(),
  );

  runApp(
    MediGoApp(
      googleWebClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
      connectionReport: report.lines,
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

/// What the build was given, and what Supabase makes of it.
class _CredentialReport {
  const _CredentialReport({required this.lines, required this.refused});

  /// Human-readable findings, in the order they should be read.
  final List<String> lines;

  /// True only when Supabase answered and rejected the key. An unreachable
  /// server leaves this false: being offline is not a bad key, and refusing
  /// to start would strand a user who only wanted to read today's doses.
  final bool refused;
}

/// Describes the credentials, then asks Supabase to judge them.
///
/// Nothing here is secret. The anon key ships inside every copy of the app,
/// and the claims shown are the key's own unencrypted middle segment.
Future<_CredentialReport> _checkCredentials() async {
  final key = _supabaseAnonKey.trim();
  final lines = <String>[
    'URL = $_trimmedSupabaseUrl',
    'key: ยาว ${key.length} ตัว, จุด ${key.split('.').length - 1} จุด, '
        'ขึ้นต้น ${key.substring(0, key.length.clamp(0, 12))}',
    'GOOGLE_WEB_CLIENT_ID = '
        '${_googleWebClientId.trim().isEmpty ? "(ว่าง — ปุ่ม Google จะไม่แสดง)" : "ตั้งค่าแล้ว"}',
  ];

  if (key.length != _supabaseAnonKey.length) {
    lines.add('หมายเหตุ: key ในไฟล์มีช่องว่างหัว/ท้าย — ตัดออกให้แล้ว');
  }

  if (key.startsWith('sb_secret_')) {
    lines.add('ชนิด: SECRET KEY — ห้ามใส่ในแอป ให้ใช้ publishable key แทน');
  } else if (key.startsWith('sb_publishable_')) {
    lines.add('ชนิด: publishable key (แบบใหม่)');
  } else {
    final parts = key.split('.');
    if (parts.length != 3) {
      lines.add('ชนิด: รูปแบบไม่ถูก — JWT ต้องมี 3 ท่อนคั่นด้วยจุด '
          '(น่าจะ copy มาไม่ครบ)');
    } else {
      try {
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        ) as Map<String, dynamic>;
        final ref = claims['ref'];
        final role = claims['role'];
        lines.add('ชนิด: legacy JWT — โปรเจกต์ $ref, role $role');
        if (role != 'anon') {
          lines.add('คำเตือน: role ควรเป็น anon ไม่ใช่ $role');
        }
        final refInUrl = Uri.parse(_trimmedSupabaseUrl).host.split('.').first;
        if (ref != refInUrl) {
          lines.add('ไม่ตรงกัน: key เป็นของ $ref แต่ URL ชี้ไป $refInUrl');
        }
      } catch (error) {
        lines.add('อ่านเนื้อใน JWT ไม่ได้: $error');
      }
    }
  }

  try {
    final response = await http
        .get(
          Uri.parse('$_trimmedSupabaseUrl/auth/v1/settings'),
          headers: {'apikey': key},
        )
        .timeout(const Duration(seconds: 8));
    lines.add('ถาม Supabase: HTTP ${response.statusCode}');
    if (response.statusCode == 200) {
      lines.add('ผล: key ใช้งานได้');
      return _CredentialReport(lines: lines, refused: false);
    }
    lines.add('Supabase ตอบ: ${response.body}');
    if (!key.startsWith('sb_')) {
      lines.add('key ถูกต้องตามรูปแบบแต่ถูกปฏิเสธ — โปรเจกต์น่าจะปิด '
          'legacy API key ไว้ ให้ไปหน้า Settings > API Keys คัดลอก '
          'Publishable key มาใส่ใน dart_defines.json แทน');
    }
    return _CredentialReport(lines: lines, refused: true);
  } catch (error) {
    // Unreachable, not rejected: let the app start.
    lines.add('ต่อ Supabase ไม่ได้ (ออฟไลน์หรือถูกบล็อก): $error');
    return _CredentialReport(lines: lines, refused: false);
  }
}

/// Shown when Supabase actively refuses the key, so the reason is on screen
/// rather than four red words under a password field.
class _RejectedConfigApp extends StatelessWidget {
  const _RejectedConfigApp(this.report);

  final _CredentialReport report;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Supabase ปฏิเสธ API key',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'แอปเปิดหน้าเข้าสู่ระบบไม่ได้ เพราะกุญแจที่ build มาใช้ไม่ได้ '
                'รายละเอียดด้านล่างคือสิ่งที่แอปได้รับและคำตอบจากเซิร์ฟเวอร์',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              for (final line in report.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('•  $line', style: const TextStyle(height: 1.5)),
                ),
              const SizedBox(height: 8),
              const Text(
                'แก้ที่ mobile/dart_defines.json แล้ว build ใหม่',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
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
