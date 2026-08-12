enum UserRole { patient, caregiver, provider, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.firstName,
    this.lastName,
    this.patientId,
    this.phone,
    this.avatarUrl,
    this.profileCompleted = false,
  });

  final String id;
  final String email;

  /// The joined display name. Everything that shows a name reads this.
  final String name;
  final UserRole role;

  /// Kept apart from [name] because the profile form asks for them
  /// separately, and splitting the display name back out on whitespace gets
  /// any name of more than two parts wrong.
  final String? firstName;
  final String? lastName;

  /// The patient record this account owns — every `patients`-scoped screen
  /// needs this, not [id]: the account and the patient are different rows.
  final String? patientId;

  final String? phone;

  /// Absolute URL into Supabase Storage, or null when no photo was uploaded.
  final String? avatarUrl;

  /// Whether the after-sign-up form has been filled in. False sends the user
  /// to that form instead of into the app.
  final bool profileCompleted;

  factory AppUser.fromProfile(Map<String, dynamic> row, {String? patientId}) {
    return AppUser(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      name: row['name'] as String? ?? '',
      role: UserRole.values.byName(row['role'] as String? ?? 'patient'),
      firstName: _trimmedOrNull(row['first_name']),
      lastName: _trimmedOrNull(row['last_name']),
      patientId: patientId,
      phone: _trimmedOrNull(row['phone']),
      avatarUrl: row['avatar_url'] as String?,
      profileCompleted: row['profile_completed_at'] != null,
    );
  }

  /// Treats an empty string the same as absent — a cleared text field arrives
  /// as '' rather than null, and a form that reads it back should show the
  /// hint, not a blank-looking value that is really there.
  static String? _trimmedOrNull(Object? value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
