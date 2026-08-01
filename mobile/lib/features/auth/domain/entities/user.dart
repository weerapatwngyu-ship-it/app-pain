enum UserRole { patient, caregiver, provider, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.patientId,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;

  /// The patient profile this account owns — set for `patient`-role
  /// accounts (auto-created on register), null otherwise. Screens that
  /// call `/patients/:id/...` need this, not [id] (the user id and the
  /// patient id are different rows/tables on the backend).
  final String? patientId;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.values.byName(json['role'] as String),
      patientId: json['patientId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'patientId': patientId,
      };
}
