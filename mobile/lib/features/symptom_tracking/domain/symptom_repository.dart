import 'entities/symptom_log.dart';

abstract class SymptomRepository {
  Future<void> recordSymptom(SymptomLog log);
}
