import '../../../core/supabase/supabase_refs.dart';

/// A patient as clinical staff see them in the caseload list.
class CaseloadPatient {
  const CaseloadPatient({
    required this.id,
    required this.name,
    required this.birthDate,
    this.gender,
    this.primaryCondition,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String? gender;
  final String? primaryCondition;

  /// Whole years, which is what a chart shows. The birth date defaults to a
  /// placeholder at sign-up until the patient fills it in, so this can read
  /// oddly for accounts that never completed their profile.
  int get age {
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    final hadBirthday = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) years -= 1;
    return years;
  }

  factory CaseloadPatient.fromRow(Map<String, dynamic> row) {
    return CaseloadPatient(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      birthDate: DateTime.parse(row['birth_date'] as String),
      gender: row['gender'] as String?,
      primaryCondition: row['primary_condition'] as String?,
    );
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
        .select('id, name, birth_date, gender, primary_condition')
        .order('name');
    return rows.map<CaseloadPatient>(CaseloadPatient.fromRow).toList();
  }

  Future<PatientRecord> record(CaseloadPatient patient) async {
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
      patient: patient,
      prescriptions:
          prescriptions.map<PrescriptionSummary>(PrescriptionSummary.fromRow).toList(),
      symptomLogs: symptoms.map<SymptomEntry>(SymptomEntry.fromRow).toList(),
      openAlerts: alerts.length,
    );
  }
}
