import '../../../core/network/api_client.dart';
import '../domain/entities/patient_profile.dart';

class PatientProfileRepository {
  PatientProfileRepository(this._client);

  final ApiClient _client;

  Future<PatientProfile> fetch(String patientId) async {
    final json = await _client.get('/patients/$patientId') as Map<String, dynamic>;
    return PatientProfile.fromJson(json);
  }
}
