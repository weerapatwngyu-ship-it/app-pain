import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/entities/user.dart';

/// Persists the logged-in session (access token + user) so the app doesn't
/// force a fresh login on every launch — only on explicit logout, or when a
/// stored token has expired and a request comes back 401.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'medtrack_access_token';
  static const _userKey = 'medtrack_user';

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _tokenKey, value: session.accessToken);
    await _storage.write(key: _userKey, value: jsonEncode(session.user.toJson()));
  }

  Future<AuthSession?> load() async {
    final token = await _storage.read(key: _tokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (token == null || userJson == null) return null;
    try {
      final user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      return AuthSession(accessToken: token, user: user);
    } catch (_) {
      // Corrupt/old-shape stored value — treat as no session rather than
      // crashing app startup.
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
