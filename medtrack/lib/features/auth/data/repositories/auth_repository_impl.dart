import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorage secureStorage,
  })  : _remote = remoteDataSource,
        _secureStorage = secureStorage;

  final AuthRemoteDataSource _remote;
  final SecureStorage _secureStorage;

  User? _cachedUser;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remote.login(email: email, password: password);
      await _secureStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      _cachedUser = result.user;
      return Success(result.user);
    } on DioException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(ServerFailure());
    }
  }

  @override
  Future<Result<User>> currentUser() async {
    if (_cachedUser case final user?) return Success(user);
    return const Error(UnauthorizedFailure());
  }

  @override
  Future<void> logout() => _secureStorage.clear();
}
