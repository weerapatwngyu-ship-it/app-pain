import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/user.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final json = await _client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    return _toSession(json as Map<String, dynamic>);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    final json = await _client.post('/auth/register', body: {
      'email': email,
      'password': password,
      'name': name,
      'role': role.name,
    });
    return _toSession(json as Map<String, dynamic>);
  }

  AuthSession _toSession(Map<String, dynamic> json) {
    final session = AuthSession(
      accessToken: json['accessToken'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
    _client.setAccessToken(session.accessToken);
    return session;
  }
}
