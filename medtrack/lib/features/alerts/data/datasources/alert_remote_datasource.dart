import '../../../../core/network/api_client.dart';
import '../models/alert_model.dart';

class AlertRemoteDataSource {
  const AlertRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AlertModel>> getOpenAlerts() async {
    final response = await _client.get('/v1/alerts', queryParameters: {'status': 'open'});
    final items = response.data['items'] as List<dynamic>;
    return items.map((json) => AlertModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<AlertModel> acknowledge(String alertId) async {
    final response = await _client.post('/v1/alerts/$alertId/acknowledge');
    return AlertModel.fromJson(response.data as Map<String, dynamic>);
  }
}
