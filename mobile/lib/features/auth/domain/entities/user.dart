enum UserRole { patient, caregiver, provider, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.patientId,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;

  /// The patient record this account owns — every `patients`-scoped screen
  /// needs this, not [id]: the account and the patient are different rows.
  final String? patientId;

  final String? phone;

  /// Absolute URL into Supabase Storage, or null when no photo was uploaded.
  final String? avatarUrl;

  factory AppUser.fromProfile(Map<String, dynamic> row, {String? patientId}) {
    return AppUser(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      name: row['name'] as String? ?? '',
      role: UserRole.values.byName(row['role'] as String? ?? 'patient'),
      patientId: patientId,
      phone: row['phone'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
