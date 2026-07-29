import '../../../../core/error/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Accepts any email/password so the app is explorable before a real
/// backend exists. Swapped out for [AuthRepositoryImpl] once
/// `Env.useMockBackend` is false.
class MockAuthRepository implements AuthRepository {
  User? _session;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _session = User(
      id: 'demo-patient-1',
      name: 'ผู้ป่วยทดสอบ',
      email: email.isEmpty ? 'demo@medtrack.local' : email,
      role: UserRole.patient,
    );
    return Success(_session!);
  }

  @override
  Future<Result<User>> currentUser() async {
    if (_session case final user?) return Success(user);
    return const Error(UnauthorizedFailure());
  }

  @override
  Future<void> logout() async {
    _session = null;
  }
}
