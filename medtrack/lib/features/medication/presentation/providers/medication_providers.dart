import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/injector.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/dose_schedule.dart';
import '../../domain/usecases/get_today_schedule_usecase.dart';
import '../../domain/usecases/log_dose_usecase.dart';

final getTodayScheduleUseCaseProvider = Provider<GetTodayScheduleUseCase>((ref) {
  return getIt<GetTodayScheduleUseCase>();
});

final logDoseUseCaseProvider = Provider<LogDoseUseCase>((ref) {
  return getIt<LogDoseUseCase>();
});

/// Fetches today's schedule for the given patient. Family key lets the
/// same provider serve a patient screen and a caregiver's view of a
/// linked patient.
final todayScheduleProvider =
    FutureProvider.family<List<DoseSchedule>, String>((ref, patientId) async {
  final useCase = ref.watch(getTodayScheduleUseCaseProvider);
  final result = await useCase(patientId);
  return result.when(
    success: (schedule) => schedule,
    failure: (failure) => throw Exception(failure.message),
  );
});

class DoseActionController extends StateNotifier<AsyncValue<void>> {
  DoseActionController(this._logDose) : super(const AsyncData(null));

  final LogDoseUseCase _logDose;

  Future<void> confirm({
    required String scheduleId,
    required DateTime scheduledAt,
    required DoseStatus status,
  }) async {
    state = const AsyncLoading();
    final result = await _logDose(
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
      status: status,
    );
    state = result.when(
      success: (_) => const AsyncData(null),
      failure: (failure) => AsyncError(failure.message, StackTrace.current),
    );
  }
}

final doseActionControllerProvider =
    StateNotifierProvider<DoseActionController, AsyncValue<void>>((ref) {
  return DoseActionController(ref.watch(logDoseUseCaseProvider));
});
