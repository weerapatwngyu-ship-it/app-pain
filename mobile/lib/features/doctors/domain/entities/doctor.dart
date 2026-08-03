class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.bio,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String specialty;
  final String? bio;

  /// Relative path returned by the backend (e.g. `/uploads/doctors/xxx.jpg`)
  /// — prepend the API server's origin, not `ApiClient.baseUrl`, to load it.
  final String? photoUrl;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
