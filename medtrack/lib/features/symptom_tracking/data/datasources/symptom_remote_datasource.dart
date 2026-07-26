import '../../../../core/network/api_client.dart';
import '../models/symptom_log_model.dart';

class SymptomRemoteDataSource {
  const SymptomRemoteDataSource(this._client);

  final ApiClient _client;

  Future<void> submitSymptomLog(SymptomLogModel log) {
    return _client.post('/v1/symptom-logs', data: log.toJson());
  }

  Future<List<SymptomLogModel>> getHistory({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      '/v1/patients/$patientId/trends',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final items = response.data['symptom_logs'] as List<dynamic>;
    return items
        .map((json) => SymptomLogModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
