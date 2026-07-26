import '../entities/symptom_log.dart';
import '../symptom_repository.dart';

class RecordSymptomUseCase {
  RecordSymptomUseCase(this._repository);

  final SymptomRepository _repository;

  Future<void> call(SymptomLog log) => _repository.recordSymptom(log);
}
