import '../../../../core/error/failure.dart';
import '../entities/symptom_log.dart';

abstract interface class SymptomRepository {
  Future<Result<SymptomLog>> recordSymptom(SymptomLog log);

  /// Symptom history for [patientId] within [from]..[to], used to draw
  /// the trend chart alongside dose adherence.
  Future<Result<List<SymptomLog>>> getHistory({
    required String patientId,
    required DateTime from,
    required DateTime to,
  });
}
