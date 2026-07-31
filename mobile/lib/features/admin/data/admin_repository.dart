import '../../../core/network/api_client.dart';
import '../domain/entities/admin_summaries.dart';

class AdminRepository {
  AdminRepository(this._client);

  final ApiClient _client;

  Future<List<AdminUserSummary>> listUsers() async {
    final json = await _client.get('/admin/users');
    return (json as List)
        .map((item) => AdminUserSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminPatientSummary>> listPatients() async {
    final json = await _client.get('/admin/patients');
    return (json as List)
        .map((item) => AdminPatientSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
