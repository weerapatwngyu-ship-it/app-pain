import '../../../core/network/api_client.dart';
import '../domain/entities/symptom_log.dart';
import '../domain/symptom_repository.dart';

class SymptomRepositoryImpl implements SymptomRepository {
  SymptomRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<void> recordSymptom(SymptomLog log) async {
    await _client.post('/symptom-logs', body: log.toJson());
  }

  @override
  Future<List<SymptomLog>> fetchLogs(String patientId, {String? category}) async {
    final path = category != null
        ? '/patients/$patientId/symptom-logs?category=$category'
        : '/patients/$patientId/symptom-logs';
    final json = await _client.get(path) as List<dynamic>;
    return json.map((e) => SymptomLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Map<String, int>> categoryCounts(String patientId) async {
    final json = await _client.get('/patients/$patientId/symptom-logs/category-counts')
        as Map<String, dynamic>;
    return json.map((key, value) => MapEntry(key, value as int));
  }
}
