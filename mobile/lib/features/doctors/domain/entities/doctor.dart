class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.userId,
    this.bio,
    this.photoUrl,
  });

  final String id;

  /// The account that signs in as this doctor, or null for a listing an admin
  /// created before (or without) an account — such a doctor appears in the
  /// directory but cannot read the messages patients send them.
  final String? userId;

  final String name;
  final String specialty;
  final String? bio;

  bool get hasAccount => userId != null;

  /// Absolute URL into Supabase Storage, or null when no photo was uploaded.
  final String? photoUrl;

  factory Doctor.fromRow(Map<String, dynamic> row) {
    return Doctor(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      specialty: row['specialty'] as String,
      bio: row['bio'] as String?,
      photoUrl: row['photo_url'] as String?,
    );
  }
}
