import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/user.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<AppUser> fetchCurrentUser() async {
    final json = await _client.get('/auth/me') as Map<String, dynamic>;
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> updateProfile({String? name, String? email}) async {
    final json = await _client.patch('/auth/profile', body: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    }) as Map<String, dynamic>;
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> uploadAvatar({required List<int> fileBytes, required String fileName}) async {
    final json = await _client.uploadFile(
      '/auth/avatar',
      fileBytes: fileBytes,
      fileName: fileName,
    ) as Map<String, dynamic>;
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}
