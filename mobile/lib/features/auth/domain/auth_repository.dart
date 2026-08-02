import 'entities/user.dart';

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final AppUser user;
}

class OtpRequestResult {
  const OtpRequestResult({required this.refCode, required this.expiresInSeconds, this.devOtp});

  final String refCode;
  final int expiresInSeconds;

  /// Only populated when the backend isn't running in production (no SMS
  /// gateway wired up yet) — lets the OTP screen show the code for testing.
  final String? devOtp;
}

class OtpVerifyResult {
  const OtpVerifyResult({required this.isNewUser});

  final bool isNewUser;
}

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  });

  Future<OtpRequestResult> requestOtp({required String phone});

  Future<OtpVerifyResult> verifyOtp({required String phone, required String otp});

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
  });

  Future<AuthSession> loginWithPhonePin({required String phone, required String pin});

  Future<AppUser> updateProfile({String? name, String? email});
}
