import '../../../core/supabase/supabase_refs.dart';
import '../../../shared/format/thai_date.dart';

/// A patient as clinical staff see them in the caseload list.
class CaseloadPatient {
  const CaseloadPatient({
    required this.id,
    required this.name,
    required this.birthDate,
    this.gender,
    this.primaryCondition,
    this.drugAllergies = const [],
    this.foodAllergies = const [],
    this.bloodType,
    this.weightKg,
    this.heightCm,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String? gender;
  final String? primaryCondition;

  /// Read here and not only on the patient's own profile: a drug allergy that
  /// the prescriber cannot see is not doing the job it exists for.
  final List<String> drugAllergies;

  final List<String> foodAllergies;

  final String? bloodType;
  final double? weightKg;
  final double? heightCm;

  /// Whether the birth date is still the placeholder written at sign-up.
  ///
  /// The column is NOT NULL, so an account that never completed its profile
  /// carries 2000-01-01 — which reads on screen as a real date of birth and an
  /// age to match. Someone genuinely born that day is flagged too; being told
  /// a date is unconfirmed when it is fine costs nothing next to treating a
  /// placeholder as fact.
  bool get birthDateUnconfirmed =>
      birthDate.year == 2000 && birthDate.month == 1 && birthDate.day == 1;

  /// Thai reading of the gender stored in the database, which uses the English
  /// values the check constraint allows.
  String? get genderLabel => switch (gender) {
        'female' => 'หญิง',
        'male' => 'ชาย',
        'unspecified' => 'ไม่ระบุ',
        _ => gender,
      };

  /// Body mass index, or null when either measurement is missing.
  double? get bmi {
    final weight = weightKg;
    final height = heightCm;
    if (weight == null || height == null || height <= 0) return null;
    final metres = height / 100;
    return weight / (metres * metres);
  }

  /// Whole years, which is what a chart shows. The birth date defaults to a
  /// placeholder at sign-up until the patient fills it in, so this can read
  /// oddly for accounts that never completed their profile — see
  /// [birthDateUnconfirmed].
  int get age => ageFrom(birthDate);

  factory CaseloadPatient.fromRow(Map<String, dynamic> row) {
    return CaseloadPatient(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      birthDate: DateTime.parse(row['birth_date'] as String),
      gender: row['gender'] as String?,
      primaryCondition: _trimmedOrNull(row['primary_condition']),
      drugAllergies: _textList(row['drug_allergies']),
      foodAllergies: _textList(row['food_allergies']),
      bloodType: _trimmedOrNull(row['blood_type']),
      weightKg: _asDouble(row['weight_kg']),
      heightCm: _asDouble(row['height_cm']),
    );
  }

  static List<String> _textList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static String? _trimmedOrNull(Object? value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// Postgres numeric arrives as either num or String depending on how the
  /// driver handles precision, so neither is assumed.
  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// A patient's clinical record, as read by staff.
class PatientRecord {
  const PatientRecord({
    required this.patient,
    required this.prescriptions,
    required this.symptomLogs,
    required this.openAlerts,
  });

  final CaseloadPatient patient;
  final List<PrescriptionSummary> prescriptions;
  final List<SymptomEntry> symptomLogs;
  final int openAlerts;
}

class PrescriptionSummary {
  const PrescriptionSummary({
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
  });

  final String medicationName;
  final String dosage;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;

  bool get isActive => endDate == null || endDate!.isAfter(DateTime.now());

  factory PrescriptionSummary.fromRow(Map<String, dynamic> row) {
    return PrescriptionSummary(
      medicationName: row['medication_name'] as String,
      dosage: row['dosage'] as String,
      frequency: row['frequency'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: row['end_date'] == null
          ? null
          : DateTime.parse(row['end_date'] as String),
    );
  }
}

class SymptomEntry {
  const SymptomEntry({required this.recordedAt, this.painScore, this.category});

  final DateTime recordedAt;
  final int? painScore;
  final String? category;

  factory SymptomEntry.fromRow(Map<String, dynamic> row) {
    return SymptomEntry(
      recordedAt: DateTime.parse(row['recorded_at'] as String).toLocal(),
      painScore: row['pain_score'] as int?,
      category: row['category'] as String?,
    );
  }
}

/// Reads across every patient, which RLS only allows for provider/admin
/// accounts (see can_view_all_patients in schema.sql). A patient calling these
/// gets back their own row and nothing else, rather than an error.
class CaseloadRepository {
  Future<List<CaseloadPatient>> patients() async {
    final rows = await db
        .from('patients')
        .select('id, name, birth_date, gender, primary_condition, '
            'drug_allergies, food_allergies, blood_type, weight_kg, height_cm')
        .order('name');
    return rows.map<CaseloadPatient>(CaseloadPatient.fromRow).toList();
  }

  /// Re-reads one patient.
  ///
  /// The list hands its own copy to the record screen, and that copy is as old
  /// as the last time the list was loaded. A record opened to check an allergy
  /// has to show what the patient has entered by now, not what they had
  /// entered when the caseload was last pulled.
  Future<CaseloadPatient> patient(String patientId) async {
    final row = await db
        .from('patients')
        .select('id, name, birth_date, gender, primary_condition, '
            'drug_allergies, food_allergies, blood_type, weight_kg, height_cm')
        .eq('id', patientId)
        .single();
    return CaseloadPatient.fromRow(row);
  }

  Future<PatientRecord> record(CaseloadPatient patient) async {
    // Falls back to the copy passed in: a refresh that fails should not empty
    // a record the caller could already display.
    CaseloadPatient current = patient;
    try {
      current = await this.patient(patient.id);
    } catch (_) {
      // Left as it was.
    }

    final prescriptions = await db
        .from('prescriptions')
        .select('medication_name, dosage, frequency, start_date, end_date')
        .eq('patient_id', patient.id)
        .order('start_date', ascending: false);

    final symptoms = await db
        .from('symptom_logs')
        .select('recorded_at, pain_score, category')
        .eq('patient_id', patient.id)
        .order('recorded_at', ascending: false)
        .limit(30);

    final alerts = await db
        .from('alerts')
        .select('id')
        .eq('patient_id', patient.id)
        .eq('status', 'open');

    return PatientRecord(
      patient: current,
      prescriptions:
          prescriptions.map<PrescriptionSummary>(PrescriptionSummary.fromRow).toList(),
      symptomLogs: symptoms.map<SymptomEntry>(SymptomEntry.fromRow).toList(),
      openAlerts: alerts.length,
    );
  }
}
