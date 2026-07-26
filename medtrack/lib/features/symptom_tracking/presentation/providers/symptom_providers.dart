import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/di/injector.dart';
import '../../domain/entities/symptom_log.dart';
import '../../domain/usecases/get_symptom_trend_usecase.dart';
import '../../domain/usecases/record_symptom_usecase.dart';

final recordSymptomUseCaseProvider = Provider<RecordSymptomUseCase>((ref) {
  return getIt<RecordSymptomUseCase>();
});

final getSymptomTrendUseCaseProvider = Provider<GetSymptomTrendUseCase>((ref) {
  return getIt<GetSymptomTrendUseCase>();
});

final symptomTrendProvider = FutureProvider.family<List<SymptomLog>,
    ({String patientId, DateTime from, DateTime to})>((ref, args) async {
  final useCase = ref.watch(getSymptomTrendUseCaseProvider);
  final result = await useCase(
    patientId: args.patientId,
    from: args.from,
    to: args.to,
  );
  return result.when(
    success: (logs) => logs,
    failure: (failure) => throw Exception(failure.message),
  );
});

class SymptomFormController extends StateNotifier<AsyncValue<void>> {
  SymptomFormController(this._recordSymptom) : super(const AsyncData(null));

  final RecordSymptomUseCase _recordSymptom;
  static const _uuid = Uuid();

  Future<void> submit({
    required String patientId,
    required int painScore,
    String? mood,
    String? notes,
  }) async {
    state = const AsyncLoading();
    final log = SymptomLog(
      id: _uuid.v4(),
      patientId: patientId,
      recordedAt: DateTime.now(),
      painScore: painScore,
      mood: mood,
      notes: notes,
    );
    final result = await _recordSymptom(log);
    state = result.when(
      success: (_) => const AsyncData(null),
      failure: (failure) => AsyncError(failure.message, StackTrace.current),
    );
  }
}

final symptomFormControllerProvider =
    StateNotifierProvider<SymptomFormController, AsyncValue<void>>((ref) {
  return SymptomFormController(ref.watch(recordSymptomUseCaseProvider));
});
