import 'entities/user.dart';

/// The app-side profile that hangs off a Supabase identity. Sign-in,
/// sign-out and session storage all belong to the Supabase client now, so
/// this only covers the profile fields the backend owns.
abstract class AuthRepository {
  /// Resolves the profile for the currently signed-in Supabase user,
  /// creating it on the backend if this is their first sign-in.
  Future<AppUser> fetchCurrentUser();

  /// Writes the profile fields the user can edit.
  ///
  /// [firstName] and [lastName] are stored as given and also joined into the
  /// display name, so callers never have to keep the two in step themselves.
  ///
  /// Setting [markCompleted] stamps the profile as filled in, which is what
  /// stops the app asking for it again. Only the after-sign-up form passes it;
  /// later edits leave the stamp alone.
  Future<AppUser> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    bool markCompleted = false,
  });

  Future<AppUser> uploadAvatar({required List<int> fileBytes, required String fileName});
}
