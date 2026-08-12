class PatientProfile {
  const PatientProfile({
    required this.birthDate,
    this.gender,
    this.primaryCondition,
    this.drugAllergies = const [],
    this.bloodType,
    this.weightKg,
    this.heightCm,
  });

  /// ISO `YYYY-MM-DD`, as stored in Postgres.
  final String birthDate;
  final String? gender;

  /// Long-term conditions, as free text. Staff see this in the caseload list.
  final String? primaryCondition;

  /// One drug per entry rather than a sentence, so it can be compared against
  /// a prescription rather than only read.
  final List<String> drugAllergies;

  /// One of A+, A-, B+, B-, AB+, AB-, O+, O-.
  final String? bloodType;

  final double? weightKg;
  final double? heightCm;

  bool get hasAllergies => drugAllergies.isNotEmpty;

  /// Body mass index, or null when either measurement is missing. Shown as a
  /// convenience — it is derived, so it is never stored.
  double? get bmi {
    final weight = weightKg;
    final height = heightCm;
    if (weight == null || height == null || height <= 0) return null;
    final metres = height / 100;
    return weight / (metres * metres);
  }

  factory PatientProfile.fromRow(Map<String, dynamic> row) {
    return PatientProfile(
      birthDate: row['birth_date'] as String,
      gender: row['gender'] as String?,
      primaryCondition: _trimmedOrNull(row['primary_condition']),
      drugAllergies: (row['drug_allergies'] as List?)
              ?.map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList() ??
          const [],
      bloodType: _trimmedOrNull(row['blood_type']),
      // Postgres numeric arrives as either num or String depending on the
      // driver's precision handling, so neither is assumed.
      weightKg: _asDouble(row['weight_kg']),
      heightCm: _asDouble(row['height_cm']),
    );
  }

  static String? _trimmedOrNull(Object? value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
