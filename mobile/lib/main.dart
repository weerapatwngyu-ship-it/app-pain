import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/notification/notification_service.dart';

/// Supabase project credentials, passed at build time:
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co
///   --dart-define=SUPABASE_ANON_KEY=<anon key>
/// The anon key is a public client key — it is safe to ship in the app, and
/// on its own grants nothing beyond what Supabase's own rules allow.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingSupabaseConfigApp());
    return;
  }

  // Supabase is the whole backend: auth, database and file storage. There
  // is no server of this app's own to point at.
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  runApp(const MedTrackApp());
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
