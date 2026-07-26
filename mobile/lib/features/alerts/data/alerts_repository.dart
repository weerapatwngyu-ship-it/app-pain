import '../../../core/network/api_client.dart';
import '../domain/entities/alert.dart';

class AlertsRepository {
  AlertsRepository(this._client);

  final ApiClient _client;

  Future<List<PatientAlert>> openAlerts() async {
    final json = await _client.get('/alerts?status=open');
    return (json as List)
        .map((item) => PatientAlert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> acknowledge(String id) => _client.post('/alerts/$id/acknowledge');
}
