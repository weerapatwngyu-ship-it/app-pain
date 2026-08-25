import '../../../core/i18n/app_locale.dart';
import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/medication.dart';

/// The patient's own medication list.
///
/// Separate from [MedicationRepositoryImpl], which answers "what is due today"
/// and writes dose logs locally first. This one manages the list itself, and
/// every call goes straight to the backend: a medication added offline and
/// held locally would produce reminders for something the record does not
/// have, which is worse than being told the save did not happen.
class MedicationListRepository {
  Future<List<Medication>> forPatient(String patientId) async {
    final rows = await db
        .from('prescriptions')
        .select('id, medication_name, dosage, frequency, start_date, '
            'end_date, source, stop_reason, dose_schedules(scheduled_time)')
        .eq('patient_id', patientId)
        .order('start_date', ascending: false);
    return rows.map<Medication>(Medication.fromRow).toList();
  }

  /// Adds a medication and its times. Returns the stored row.
  ///
  /// [bySelf] decides who the row belongs to, and the database enforces the
  /// difference: a patient may only write rows marked 'self', and only a
  /// clinician's policy accepts 'clinician'. Passing the wrong one is refused
  /// rather than silently mislabelled.
  Future<Medication> add({
    required String patientId,
    required String name,
    required String dosage,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    required List<String> times,
    bool bySelf = true,
  }) async {
    final row = await db
        .from('prescriptions')
        .insert({
          'patient_id': patientId,
          'medication_name': name,
          'dosage': dosage,
          'frequency': frequency,
          'start_date': _isoDate(startDate),
          'end_date': endDate == null ? null : _isoDate(endDate),
          'source': bySelf ? 'self' : 'clinician',
        })
        .select('id')
        .single();

    final id = row['id'] as String;
    if (times.isNotEmpty) {
      await db.from('dose_schedules').insert([
        for (final time in times)
          {'prescription_id': id, 'scheduled_time': time}
      ]);
    }
    return (await forPatient(patientId)).firstWhere((m) => m.id == id);
  }

  /// Stops a medication by giving it an end date, rather than deleting the row.
  /// The dose logs against it are a record of what was actually taken, and
  /// deleting the prescription would cascade them away.
  ///
  /// [endDate] is the last day the medication counts as prescribed, and today
  /// by default. A doctor stopping treatment because the patient has recovered
  /// may want it to stop before today's remaining doses instead — only they
  /// know which, so the caller decides rather than this method.
  ///
  /// [recovered] records *why* it ended. An end date says a drug stopped; it
  /// does not say whether that was the treatment working or the treatment
  /// being abandoned, and that is the difference the next clinician reading
  /// this chart cares about.
  Future<void> stop(
    String medicationId, {
    DateTime? endDate,
    bool recovered = false,
  }) async {
    final updated = await db
        .from('prescriptions')
        .update({
          'end_date': _isoDate(endDate ?? DateTime.now()),
          'stop_reason': recovered ? 'recovered' : 'other',
        })
        .eq('id', medicationId)
        .select();
    if (updated.isEmpty) {
      // Nothing matched, which under RLS means the row exists but the caller
      // may not touch it — a patient reaching for a clinician's order, or a
      // doctor no longer in charge of this patient.
      throw StateError(t(
        'หยุดยาไม่สำเร็จ — ไม่มีสิทธิ์แก้รายการนี้',
        'Could not stop it — you do not have permission to change this entry',
      ));
    }
  }

  /// Deletes the prescription outright, along with its times and the record of
  /// every dose taken against it.
  ///
  /// For an order written by mistake. Stopping is what ends treatment: it
  /// keeps the history, and a patient's medication record with the doses cut
  /// out of it is a worse record than one showing a drug that was stopped.
  Future<void> remove(String medicationId) async {
    final deleted = await db
        .from('prescriptions')
        .delete()
        .eq('id', medicationId)
        .select();
    if (deleted.isEmpty) {
      throw StateError(t(
        'ลบไม่สำเร็จ — ไม่มีสิทธิ์ลบรายการนี้',
        'Could not delete it — you do not have permission to remove this entry',
      ));
    }
  }

  static String _isoDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
