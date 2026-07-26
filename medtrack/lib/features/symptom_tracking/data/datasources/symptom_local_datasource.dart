import 'package:uuid/uuid.dart';

import '../../../../core/storage/local_database.dart';
import '../models/symptom_log_model.dart';

class SymptomLocalDataSource {
  SymptomLocalDataSource(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalDatabase _db;
  final Uuid _uuid;

  Future<SymptomLogModel> insert(SymptomLogModel log) async {
    final withId = log.id.isEmpty
        ? SymptomLogModel.fromEntity(
            SymptomLogModel(
              id: _uuid.v4(),
              patientId: log.patientId,
              recordedAt: log.recordedAt,
              painScore: log.painScore,
              mood: log.mood,
              notes: log.notes,
              customFields: log.customFields,
            ),
          )
        : log;
    await _db.raw.insert('symptom_logs', withId.toDb());
    return withId;
  }

  Future<List<SymptomLogModel>> readHistory({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.raw.query(
      'symptom_logs',
      where: 'patient_id = ? AND recorded_at BETWEEN ? AND ?',
      whereArgs: [patientId, from.toIso8601String(), to.toIso8601String()],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(SymptomLogModel.fromDb).toList();
  }
}
