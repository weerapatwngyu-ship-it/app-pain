class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AdminPatientSummary {
  const AdminPatientSummary({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.birthDate,
    this.primaryCondition,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String birthDate;
  final String? primaryCondition;

  factory AdminPatientSummary.fromJson(Map<String, dynamic> json) {
    return AdminPatientSummary(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      name: json['name'] as String,
      birthDate: json['birthDate'] as String,
      primaryCondition: json['primaryCondition'] as String?,
    );
  }
}
