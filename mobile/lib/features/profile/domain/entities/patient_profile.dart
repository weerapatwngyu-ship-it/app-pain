class PatientProfile {
  const PatientProfile({required this.birthDate, this.gender});

  /// ISO `YYYY-MM-DD`, as stored/returned by the backend.
  final String birthDate;
  final String? gender;

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      birthDate: json['birthDate'] as String,
      gender: json['gender'] as String?,
    );
  }
}
