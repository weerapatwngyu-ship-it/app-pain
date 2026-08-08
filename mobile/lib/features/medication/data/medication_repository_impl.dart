import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/storage/local_database.dart';
import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/dose_log.dart';
import '../domain/entities/dose_schedule_item.dart';
import '../domain/medication_repository.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl(this._localDb);

  final LocalDatabase _localDb;
  static const _uuid = Uuid();

  @override
  Future<List<DoseScheduleItem>> todaySchedule(String patientId) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    // A schedule row only knows its prescription, so the medication name and
    // dose come in through the relation. `!inner` makes the join filtering,
    // so a schedule whose prescription has ended drops out entirely.
    final rows = await db
        .from('dose_schedules')
        .select('id, scheduled_time, is_prn, '
            'prescriptions!inner(medication_name, dosage, patient_id, start_date, end_date)')
        .eq('prescriptions.patient_id', patientId)
        .lte('prescriptions.start_date', today)
        .or('end_date.is.null,end_date.gte.$today', referencedTable: 'prescriptions')
        .order('scheduled_time');

    return rows.map<DoseScheduleItem>(DoseScheduleItem.fromRow).toList();
  }

  @override
  Future<void> logDose(DoseLog log) async {
    final id = _uuid.v4();
    // Write-local-first: queue survives app restarts and offline periods,
    // then drains via [syncPending] once connectivity returns.
    await _localDb.enqueue(id, 'dose_log', jsonEncode(log.toRow()));
    try {
      await db.from('dose_logs').insert(log.toRow());
      await _localDb.markSynced(id);
    } catch (_) {
      // Left queued; a background sync pass will retry.
    }
  }

  Future<void> syncPending() async {
    final pending = await _localDb.pendingSyncItems();
    for (final row in pending) {
      if (row['entity_type'] != 'dose_log') continue;
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      try {
        await db.from('dose_logs').insert(payload);
        await _localDb.markSynced(row['id'] as String);
      } catch (_) {
        // Keep retrying on the next sync pass.
      }
    }
  }
}
