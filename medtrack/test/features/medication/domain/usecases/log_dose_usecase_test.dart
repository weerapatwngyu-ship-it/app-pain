import 'package:flutter_test/flutter_test.dart';
import 'package:medtrack/core/error/failure.dart';
import 'package:medtrack/features/medication/domain/entities/dose_log.dart';
import 'package:medtrack/features/medication/domain/repositories/medication_repository.dart';
import 'package:medtrack/features/medication/domain/usecases/log_dose_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockMedicationRepository extends Mock implements MedicationRepository {}

void main() {
  late _MockMedicationRepository repository;
  late LogDoseUseCase useCase;

  setUp(() {
    repository = _MockMedicationRepository();
    useCase = LogDoseUseCase(repository);
  });

  final scheduledAt = DateTime(2026, 7, 26, 8, 0);

  test('returns the logged dose on success', () async {
    final expected = DoseLog(
      id: 'log-1',
      scheduleId: 'schedule-1',
      scheduledAt: scheduledAt,
      status: DoseStatus.taken,
      actionedAt: scheduledAt,
    );
    when(
      () => repository.logDose(
        scheduleId: 'schedule-1',
        scheduledAt: scheduledAt,
        status: DoseStatus.taken,
      ),
    ).thenAnswer((_) async => Success(expected));

    final result = await useCase(
      scheduleId: 'schedule-1',
      scheduledAt: scheduledAt,
      status: DoseStatus.taken,
    );

    expect(
      result.when(success: (log) => log, failure: (_) => null),
      expected,
    );
  });

  test('propagates a failure from the repository', () async {
    when(
      () => repository.logDose(
        scheduleId: 'schedule-1',
        scheduledAt: scheduledAt,
        status: DoseStatus.skipped,
      ),
    ).thenAnswer((_) async => const Error(NetworkFailure()));

    final result = await useCase(
      scheduleId: 'schedule-1',
      scheduledAt: scheduledAt,
      status: DoseStatus.skipped,
    );

    expect(result, isA<Error<DoseLog>>());
  });
}
