import '../../../../core/error/failure.dart';
import '../../domain/entities/symptom_log.dart';
import '../../domain/repositories/symptom_repository.dart';

/// In-memory pain-score history (trending down) so the dashboard chart
/// has something to draw before a real backend is wired up.
class MockSymptomRepository implements SymptomRepository {
  final List<SymptomLog> _logs = _buildDemoHistory();

  static List<SymptomLog> _buildDemoHistory() {
    final now = DateTime.now();
    const scores = [6, 5, 6, 4, 3, 4, 2, 3, 2, 2];
    return List.generate(scores.length, (i) {
      final day = now.subtract(Duration(days: scores.length - i));
      return SymptomLog(
        id: 'sym-$i',
        patientId: 'demo-patient-1',
        recordedAt: day,
        painScore: scores[i],
      );
    });
  }

  @override
  Future<Result<SymptomLog>> recordSymptom(SymptomLog log) async {
    _logs.add(log);
    return Success(log);
  }

  @override
  Future<Result<List<SymptomLog>>> getHistory({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final upperBound = to.add(const Duration(days: 1));
    final inRange = _logs
        .where((log) => log.recordedAt.isAfter(from) && log.recordedAt.isBefore(upperBound))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return Success(inRange);
  }
}
