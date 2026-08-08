import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/symptom_log.dart';
import '../domain/symptom_repository.dart';

class SymptomRepositoryImpl implements SymptomRepository {
  @override
  Future<void> recordSymptom(SymptomLog log) async {
    await db.from('symptom_logs').insert(log.toRow());
  }

  @override
  Future<List<SymptomLog>> fetchLogs(String patientId, {String? category}) async {
    var query = db.from('symptom_logs').select().eq('patient_id', patientId);
    if (category != null) query = query.eq('category', category);
    final rows = await query.order('recorded_at', ascending: false);
    return rows.map<SymptomLog>(SymptomLog.fromRow).toList();
  }

  @override
  Future<Map<String, int>> categoryCounts(String patientId) async {
    // Postgres can group this server-side, but that needs a database
    // function; for the handful of logs one patient has, counting the
    // category column client-side is simpler and fast enough.
    final rows = await db
        .from('symptom_logs')
        .select('category')
        .eq('patient_id', patientId)
        .not('category', 'is', null);

    final counts = <String, int>{};
    for (final row in rows) {
      final category = row['category'] as String?;
      if (category == null) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }
}
