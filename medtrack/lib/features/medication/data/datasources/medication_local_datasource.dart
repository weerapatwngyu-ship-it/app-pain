import 'package:uuid/uuid.dart';

import '../../../../core/storage/local_database.dart';
import '../models/dose_log_model.dart';
import '../models/dose_schedule_model.dart';

/// Local mirror used both as an offline cache (schedule) and as the
/// write-ahead log for dose confirmations before they're synced.
class MedicationLocalDataSource {
  MedicationLocalDataSource(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalDatabase _db;
  final Uuid _uuid;

  Future<void> cacheSchedule(List<DoseScheduleModel> schedule) async {
    final batch = _db.raw.batch();
    for (final item in schedule) {
      batch.insert('dose_schedule_cache', item.toDb());
    }
    await batch.commit(noResult: true);
  }

  Future<List<DoseScheduleModel>> readCachedSchedule() async {
    final rows = await _db.raw.query('dose_schedule_cache');
    return rows.map(DoseScheduleModel.fromDb).toList();
  }

  Future<DoseLogModel> insertDoseLog(DoseLogModel log) async {
    final withId = log.id.isEmpty
        ? DoseLogModel(
            id: _uuid.v4(),
            scheduleId: log.scheduleId,
            scheduledAt: log.scheduledAt,
            status: log.status,
            actionedAt: log.actionedAt,
          )
        : log;
    await _db.raw.insert('dose_logs', withId.toDb());
    await _db.raw.insert('sync_queue', {
      'id': _uuid.v4(),
      'entity_type': 'dose_log',
      'entity_id': withId.id,
      'payload': withId.toDb().toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
    return withId;
  }
}
