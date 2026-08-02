import '../../../core/network/api_client.dart';
import '../domain/entities/patient_profile.dart';

class PatientProfileRepository {
  PatientProfileRepository(this._client);

  final ApiClient _client;

  Future<PatientProfile> fetch(String patientId) async {
    final json = await _client.get('/patients/$patientId') as Map<String, dynamic>;
    return PatientProfile.fromJson(json);
  }

  Future<PatientProfile> update(
    String patientId, {
    String? name,
    String? birthDate,
    String? gender,
  }) async {
    final json = await _client.patch('/patients/$patientId', body: {
      if (name != null) 'name': name,
      if (birthDate != null) 'birthDate': birthDate,
      if (gender != null) 'gender': gender,
    }) as Map<String, dynamic>;
    return PatientProfile.fromJson(json);
  }
}
