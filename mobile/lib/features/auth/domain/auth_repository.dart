import 'entities/user.dart';

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final AppUser user;
}

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  });
}
