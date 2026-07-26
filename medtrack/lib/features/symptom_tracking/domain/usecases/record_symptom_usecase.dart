import '../../../../core/error/failure.dart';
import '../entities/symptom_log.dart';
import '../repositories/symptom_repository.dart';

class RecordSymptomUseCase {
  const RecordSymptomUseCase(this._repository);

  final SymptomRepository _repository;

  Future<Result<SymptomLog>> call(SymptomLog log) {
    return _repository.recordSymptom(log);
  }
}
