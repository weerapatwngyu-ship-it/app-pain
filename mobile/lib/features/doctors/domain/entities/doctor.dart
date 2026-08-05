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

  /// Absolute URL into Supabase Storage, or null when no photo was uploaded.
  final String? photoUrl;

  factory Doctor.fromRow(Map<String, dynamic> row) {
    return Doctor(
      id: row['id'] as String,
      name: row['name'] as String,
      specialty: row['specialty'] as String,
      bio: row['bio'] as String?,
      photoUrl: row['photo_url'] as String?,
    );
  }
}
