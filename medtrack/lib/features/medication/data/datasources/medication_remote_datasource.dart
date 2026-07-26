import '../../../../core/network/api_client.dart';
import '../models/dose_log_model.dart';
import '../models/dose_schedule_model.dart';

class MedicationRemoteDataSource {
  const MedicationRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<DoseScheduleModel>> getTodaySchedule(String patientId) async {
    final response = await _client.get('/v1/patients/$patientId/schedule/today');
    final items = response.data['items'] as List<dynamic>;
    return items
        .map((json) => DoseScheduleModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitDoseLog(DoseLogModel log) {
    return _client.post('/v1/dose-logs', data: log.toJson());
  }

  Future<double> getAdherenceRate({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      '/v1/patients/$patientId/adherence',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    return (response.data['rate'] as num).toDouble();
  }
}
