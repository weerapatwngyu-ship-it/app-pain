import '../../../../core/error/failure.dart';
import '../entities/symptom_log.dart';
import '../repositories/symptom_repository.dart';

class GetSymptomTrendUseCase {
  const GetSymptomTrendUseCase(this._repository);

  final SymptomRepository _repository;

  Future<Result<List<SymptomLog>>> call({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) {
    return _repository.getHistory(patientId: patientId, from: from, to: to);
  }
}
