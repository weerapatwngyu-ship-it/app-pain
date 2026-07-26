import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_database.dart';
import '../domain/entities/dose_log.dart';
import '../domain/entities/dose_schedule_item.dart';
import '../domain/medication_repository.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl(this._client, this._localDb);

  final ApiClient _client;
  final LocalDatabase _localDb;
  static const _uuid = Uuid();

  @override
  Future<List<DoseScheduleItem>> todaySchedule(String patientId) async {
    final json = await _client.get('/patients/$patientId/schedule/today');
    return (json as List)
        .map((item) => DoseScheduleItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> logDose(DoseLog log) async {
    final id = _uuid.v4();
    // Write-local-first: queue survives app restarts and offline periods,
    // then drains via [syncPending] once connectivity returns.
    await _localDb.enqueue(id, 'dose_log', jsonEncode(log.toJson()));
    try {
      await _client.post('/dose-logs', body: log.toJson());
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
        await _client.post('/dose-logs', body: payload);
        await _localDb.markSynced(row['id'] as String);
      } catch (_) {
        // Keep retrying on the next sync pass.
      }
    }
  }
}
