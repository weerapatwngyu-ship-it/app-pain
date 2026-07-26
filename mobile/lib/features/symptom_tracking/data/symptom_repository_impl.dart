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
}
