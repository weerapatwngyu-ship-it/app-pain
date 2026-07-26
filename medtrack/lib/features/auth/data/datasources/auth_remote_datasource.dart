import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<({UserModel user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'เข้าสู่ระบบไม่สำเร็จ');
    }

    final data = response.data as Map<String, dynamic>;
    return (
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }
}
