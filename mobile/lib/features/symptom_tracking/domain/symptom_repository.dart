import 'entities/symptom_log.dart';

abstract class SymptomRepository {
  Future<void> recordSymptom(SymptomLog log);

  Future<List<SymptomLog>> fetchLogs(String patientId, {String? category});

  /// Maps category key -> number of logged entries, for showing counts on
  /// the home screen without fetching every log.
  Future<Map<String, int>> categoryCounts(String patientId);
}
