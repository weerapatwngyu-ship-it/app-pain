import 'entities/user.dart';

/// The app-side profile that hangs off a Supabase identity. Sign-in,
/// sign-out and session storage all belong to the Supabase client now, so
/// this only covers the profile fields the backend owns.
abstract class AuthRepository {
  /// Resolves the profile for the currently signed-in Supabase user,
  /// creating it on the backend if this is their first sign-in.
  Future<AppUser> fetchCurrentUser();

  Future<AppUser> updateProfile({String? name, String? email});

  Future<AppUser> uploadAvatar({required List<int> fileBytes, required String fileName});
}
