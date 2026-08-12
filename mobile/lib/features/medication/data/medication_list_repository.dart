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
            'end_date, source, dose_schedules(scheduled_time)')
        .eq('patient_id', patientId)
        .order('start_date', ascending: false);
    return rows.map<Medication>(Medication.fromRow).toList();
  }

  /// Adds a medication and its times. Returns the stored row.
  ///
  /// `source` is sent explicitly because the column defaults to 'clinician'
  /// for the rows that already existed — leaving it off here would create a
  /// row the patient is then refused permission to edit.
  Future<Medication> add({
    required String patientId,
    required String name,
    required String dosage,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    required List<String> times,
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
          'source': 'self',
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

  /// Stops a medication by ending it today, rather than deleting the row.
  /// The dose logs against it are a record of what was actually taken, and
  /// deleting the prescription would cascade them away.
  Future<void> stop(String medicationId) async {
    final updated = await db
        .from('prescriptions')
        .update({'end_date': _isoDate(DateTime.now())})
        .eq('id', medicationId)
        .select();
    if (updated.isEmpty) {
      throw StateError('หยุดยาไม่สำเร็จ — รายการนี้แก้ไขได้เฉพาะผู้ที่เพิ่มไว้');
    }
  }

  /// Removes a medication the patient added. Refused by the backend for
  /// anything a clinician entered.
  Future<void> remove(String medicationId) async {
    final deleted = await db
        .from('prescriptions')
        .delete()
        .eq('id', medicationId)
        .select();
    if (deleted.isEmpty) {
      throw StateError('ลบไม่สำเร็จ — รายการนี้ลบได้เฉพาะผู้ที่เพิ่มไว้');
    }
  }

  static String _isoDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
