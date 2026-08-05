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

  /// Relative path returned by the backend (e.g. `/images/<uuid>`) —
  /// callers prepend `ApiClient.baseUrl` to load it.
  final String? avatarUrl;

  /// The patient profile this account owns — set for `patient`-role
  /// accounts (auto-created on register), null otherwise. Screens that
  /// call `/patients/:id/...` need this, not [id] (the user id and the
  /// patient id are different rows/tables on the backend).
  final String? patientId;

  /// Set for accounts created via the phone/OTP flow, null for accounts
  /// created via email/password.
  final String? phone;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.values.byName(json['role'] as String),
      patientId: json['patientId'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'patientId': patientId,
        'phone': phone,
        'avatarUrl': avatarUrl,
      };
}
