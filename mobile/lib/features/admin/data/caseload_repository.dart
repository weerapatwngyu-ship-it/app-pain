import '../../../core/supabase/supabase_refs.dart';
import '../../../core/i18n/app_locale.dart';
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

  /// The gender in the reader's language. The column holds the English values
  /// the check constraint allows, which is not what either a Thai or an
  /// English clinician should be reading off a chart.
  String? get genderLabel => switch (gender) {
        'female' => t('หญิง', 'Female'),
        'male' => t('ชาย', 'Male'),
        'unspecified' => t('ไม่ระบุ', 'Not specified'),
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
    required this.adherence,
    required this.doseLogs,
    required this.missedDoses,
  });

  final CaseloadPatient patient;
  final List<PrescriptionSummary> prescriptions;
  final List<SymptomEntry> symptomLogs;
  final int openAlerts;

  /// How the last week of doses actually went.
  final DoseAdherence adherence;

  /// The most recent doses, newest first.
  final List<DoseLogEntry> doseLogs;

  /// Doses that came due in the same window and were never answered, newest
  /// first. Derived, not stored — see [MissedDose].
  final List<MissedDose> missedDoses;
}

/// A week of doses, counted rather than estimated.
///
/// [expected] is worked out from the schedule — one dose per scheduled time
/// per day the prescription was running — and not from how many logs exist.
/// Counting only the logs would rate a patient who ignores the app entirely
/// at 100%, since every log they did write says "taken". The gap between
/// expected and logged is the whole point of showing this to a doctor.
class DoseAdherence {
  const DoseAdherence({
    required this.expected,
    required this.taken,
    required this.skipped,
  });

  final int expected;
  final int taken;
  final int skipped;

  /// Doses that came due and were never answered either way.
  int get unanswered {
    final left = expected - taken - skipped;
    return left < 0 ? 0 : left;
  }

  /// null when nothing was due — a rate over no doses is not 0%, it is
  /// nothing to report.
  double? get takenRate => expected == 0 ? null : taken / expected;

  bool get hasSchedule => expected > 0;
}

/// A dose that came due and was never answered — neither taken nor skipped.
///
/// Derived at read time from the schedule rather than stored as a row. Writing
/// "missed" rows would need something to run when a dose lapses, and the case
/// that matters most is precisely the one where the patient stopped opening
/// the app at all — so nothing would be there to write them. Deriving it means
/// the gap shows up whether or not anyone has touched the phone.
class MissedDose {
  const MissedDose({required this.medicationName, required this.scheduledAt});

  final String medicationName;

  /// The local date and time the dose was due.
  final DateTime scheduledAt;
}

class DoseLogEntry {
  const DoseLogEntry({
    required this.medicationName,
    required this.scheduledAt,
    required this.status,
    this.actionedAt,
  });

  final String medicationName;
  final DateTime scheduledAt;
  final DateTime? actionedAt;

  /// 'taken' | 'skipped' | 'missed', as the database constrains it.
  final String status;
}

class PrescriptionSummary {
  const PrescriptionSummary({
    required this.id,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.stopReason,
  });

  /// Needed so the doctor's screen can stop or remove this exact row.
  final String id;

  final String medicationName;
  final String dosage;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;

  /// 'recovered' | 'other', or null for a medication still running — or one
  /// stopped before the column existed, which is why null is not read as
  /// "no reason applied".
  final String? stopReason;

  /// Stopped because the patient got better, rather than because the drug was
  /// changed or abandoned. The chart shows this as "หายแล้ว".
  bool get stoppedRecovered => !isActive && stopReason == 'recovered';

  /// end_date is a date, so "ends today" has to count as still running —
  /// comparing a midnight DateTime against now would call today's last day
  /// finished from one minute past midnight.
  bool get isActive {
    final end = endDate;
    if (end == null) return true;
    final now = DateTime.now();
    return !DateTime(end.year, end.month, end.day)
        .isBefore(DateTime(now.year, now.month, now.day));
  }

  factory PrescriptionSummary.fromRow(Map<String, dynamic> row) {
    return PrescriptionSummary(
      id: row['id'] as String,
      medicationName: row['medication_name'] as String,
      dosage: row['dosage'] as String,
      frequency: row['frequency'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: row['end_date'] == null
          ? null
          : DateTime.parse(row['end_date'] as String),
      stopReason: row['stop_reason'] as String?,
    );
  }
}

class SymptomEntry {
  const SymptomEntry({
    required this.recordedAt,
    this.painScore,
    this.category,
    this.note,
  });

  final DateTime recordedAt;
  final int? painScore;
  final String? category;

  /// What the patient wrote in their own words, if anything.
  final String? note;

  factory SymptomEntry.fromRow(Map<String, dynamic> row) {
    final custom = row['custom_fields'] as Map<String, dynamic>?;
    final note = (custom?['note'] as String?)?.trim();
    return SymptomEntry(
      recordedAt: DateTime.parse(row['recorded_at'] as String).toLocal(),
      painScore: row['pain_score'] as int?,
      category: row['category'] as String?,
      note: (note == null || note.isEmpty) ? null : note,
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
        .order('name', ascending: true);
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
        .select('id, medication_name, dosage, frequency, start_date, end_date, '
            'source, stop_reason')
        .eq('patient_id', patient.id)
        .order('start_date', ascending: false);

    final symptoms = await db
        .from('symptom_logs')
        // custom_fields carries the note the patient typed, which is the most
        // informative part of an entry — "ปวดหลังอาหารเที่ยง" says more than a
        // category and a number ever will. It was not being selected, so the
        // doctor could see that something was logged but not what.
        .select('recorded_at, pain_score, category, custom_fields')
        .eq('patient_id', patient.id)
        .order('recorded_at', ascending: false)
        .limit(30);

    final alerts = await db
        .from('alerts')
        .select('id')
        .eq('patient_id', patient.id)
        .eq('status', 'open');

    final (adherence, doseLogs, missedDoses) = await _doses(patient.id);

    return PatientRecord(
      patient: current,
      prescriptions:
          prescriptions.map<PrescriptionSummary>(PrescriptionSummary.fromRow).toList(),
      symptomLogs: symptoms.map<SymptomEntry>(SymptomEntry.fromRow).toList(),
      openAlerts: alerts.length,
      adherence: adherence,
      missedDoses: missedDoses,
      doseLogs: doseLogs,
    );
  }

  /// How many days of dose history the record shows.
  static const _adherenceDays = 7;

  /// The last week of doses: what was due, and what the patient did about it.
  ///
  /// Read in two queries rather than one nested join. The schedule is needed
  /// in full anyway — working out what was due means walking every day of the
  /// window against each schedule's own start and end dates — and once it is
  /// in hand, the logs only have to be fetched by id.
  Future<(DoseAdherence, List<DoseLogEntry>, List<MissedDose>)> _doses(
      String patientId) async {
    final scheduleRows = await db
        .from('dose_schedules')
        .select('id, scheduled_time, is_prn, '
            'prescriptions!inner(medication_name, patient_id, start_date, end_date)')
        .eq('prescriptions.patient_id', patientId);

    if (scheduleRows.isEmpty) {
      return (
        const DoseAdherence(expected: 0, taken: 0, skipped: 0),
        const <DoseLogEntry>[],
        const <MissedDose>[],
      );
    }

    final names = <String, String>{};
    final schedules = <_ScheduleWindow>[];
    for (final row in scheduleRows) {
      final id = row['id'] as String;
      final prescription =
          row['prescriptions'] as Map<String, dynamic>? ?? const {};
      names[id] = prescription['medication_name'] as String? ?? '';

      // A PRN dose is taken when it is needed, so it was never "due" and
      // counting it as a miss would invent non-adherence out of nothing.
      if (row['is_prn'] as bool? ?? false) continue;

      final time = _parseTime(row['scheduled_time'] as String? ?? '');
      final start = DateTime.tryParse(prescription['start_date'] as String? ?? '');
      if (time == null || start == null) continue;
      final end = DateTime.tryParse(prescription['end_date'] as String? ?? '');
      schedules.add(_ScheduleWindow(
        scheduleId: id,
        medicationName: names[id] ?? '',
        minuteOfDay: time,
        start: DateTime(start.year, start.month, start.day),
        end: end == null ? null : DateTime(end.year, end.month, end.day),
      ));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowStart = today.subtract(const Duration(days: _adherenceDays - 1));

    // Read before the day walk below, which needs to know what was answered
    // in order to name what was not.
    final logRows = await db
        .from('dose_logs')
        .select('schedule_id, scheduled_at, actioned_at, status')
        .inFilter('schedule_id', names.keys.toList())
        // toUtc, or a local midnight is read as UTC midnight and the window
        // silently starts seven hours late.
        .gte('scheduled_at', windowStart.toUtc().toIso8601String())
        .order('scheduled_at', ascending: false);

    var taken = 0;
    var skipped = 0;
    final entries = <DoseLogEntry>[];
    // "schedule|yyyy-mm-dd" for every slot the patient answered either way.
    // Keyed by day rather than by exact minute: one schedule is one dose a
    // day, and a patient who takes an 08:00 tablet at 11:00 has answered it,
    // not missed it and taken a phantom extra.
    final answered = <String>{};
    for (final row in logRows) {
      final status = row['status'] as String? ?? '';
      if (status == 'taken') taken++;
      if (status == 'skipped') skipped++;
      final scheduledAt =
          DateTime.parse(row['scheduled_at'] as String).toLocal();
      answered.add('${row['schedule_id']}|${_dayKey(scheduledAt)}');
      entries.add(DoseLogEntry(
        medicationName: names[row['schedule_id']] ?? '',
        scheduledAt: scheduledAt,
        actionedAt: row['actioned_at'] == null
            ? null
            : DateTime.parse(row['actioned_at'] as String).toLocal(),
        status: status,
      ));
    }

    var expected = 0;
    final missed = <MissedDose>[];
    for (var day = windowStart;
        !day.isAfter(today);
        day = day.add(const Duration(days: 1))) {
      for (final schedule in schedules) {
        if (day.isBefore(schedule.start)) continue;
        if (schedule.end != null && day.isAfter(schedule.end!)) continue;
        // A dose later today has not been missed yet — counting it would show
        // a patient falling behind every morning and catching up by night.
        if (day.isAtSameMomentAs(today) &&
            schedule.minuteOfDay > now.hour * 60 + now.minute) {
          continue;
        }
        expected++;
        if (answered.contains('${schedule.scheduleId}|${_dayKey(day)}')) {
          continue;
        }
        // Due, and nothing was ever recorded against it. This is the whole
        // point: a doctor cannot act on "adherence 71%", but can act on
        // "missed the 20:00 dose four evenings running".
        missed.add(MissedDose(
          medicationName: schedule.medicationName,
          scheduledAt: DateTime(day.year, day.month, day.day,
              schedule.minuteOfDay ~/ 60, schedule.minuteOfDay % 60),
        ));
      }
    }
    missed.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return (
      DoseAdherence(expected: expected, taken: taken, skipped: skipped),
      entries,
      missed,
    );
  }

  static String _dayKey(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  /// 'HH:mm' or 'HH:mm:ss' as minutes past midnight.
  static int? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}

/// One scheduled time, with the days its prescription was actually running.
class _ScheduleWindow {
  const _ScheduleWindow({
    required this.scheduleId,
    required this.medicationName,
    required this.minuteOfDay,
    required this.start,
    required this.end,
  });

  final String scheduleId;
  final String medicationName;
  final int minuteOfDay;
  final DateTime start;
  final DateTime? end;
}
