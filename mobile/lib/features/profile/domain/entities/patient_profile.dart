class PatientProfile {
  const PatientProfile({required this.birthDate, this.gender});

  /// ISO `YYYY-MM-DD`, as stored in Postgres.
  final String birthDate;
  final String? gender;

  factory PatientProfile.fromRow(Map<String, dynamic> row) {
    return PatientProfile(
      birthDate: row['birth_date'] as String,
      gender: row['gender'] as String?,
    );
  }
}
