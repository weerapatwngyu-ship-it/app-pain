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

  @override
  Future<OtpRequestResult> requestOtp({required String phone}) async {
    final json = await _client.post('/auth/otp/request', body: {'phone': phone})
        as Map<String, dynamic>;
    return OtpRequestResult(
      refCode: json['refCode'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int,
      devOtp: json['devOtp'] as String?,
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({required String phone, required String otp}) async {
    final json = await _client.post('/auth/otp/verify', body: {'phone': phone, 'otp': otp})
        as Map<String, dynamic>;
    return OtpVerifyResult(isNewUser: json['isNewUser'] as bool);
  }

  @override
  Future<AuthSession> registerWithPhone({
    required String phone,
    required String pin,
    required bool consentHealth,
    required bool consentMarketing,
    required String firstName,
    required String lastName,
    required String email,
    required String birthDate,
    String? gender,
  }) async {
    final json = await _client.post('/auth/register-phone', body: {
      'phone': phone,
      'pin': pin,
      'consentHealth': consentHealth,
      'consentMarketing': consentMarketing,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'birthDate': birthDate,
      if (gender != null) 'gender': gender,
    });
    return _toSession(json as Map<String, dynamic>);
  }

  @override
  Future<AuthSession> loginWithPhonePin({required String phone, required String pin}) async {
    final json =
        await _client.post('/auth/login-phone-pin', body: {'phone': phone, 'pin': pin});
    return _toSession(json as Map<String, dynamic>);
  }

  @override
  Future<AppUser> updateProfile({String? name, String? email}) async {
    final json = await _client.patch('/auth/profile', body: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    }) as Map<String, dynamic>;
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
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
