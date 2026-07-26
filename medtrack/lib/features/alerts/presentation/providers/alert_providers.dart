import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/injector.dart';
import '../../domain/entities/alert.dart';
import '../../domain/usecases/acknowledge_alert_usecase.dart';
import '../../domain/usecases/get_open_alerts_usecase.dart';

final getOpenAlertsUseCaseProvider = Provider<GetOpenAlertsUseCase>((ref) {
  return getIt<GetOpenAlertsUseCase>();
});

final acknowledgeAlertUseCaseProvider = Provider<AcknowledgeAlertUseCase>((ref) {
  return getIt<AcknowledgeAlertUseCase>();
});

final openAlertsProvider = FutureProvider<List<Alert>>((ref) async {
  final result = await ref.watch(getOpenAlertsUseCaseProvider)();
  return result.when(
    success: (alerts) => alerts,
    failure: (failure) => throw Exception(failure.message),
  );
});

final acknowledgeAlertProvider =
    FutureProvider.family<Alert, String>((ref, alertId) async {
  final result = await ref.watch(acknowledgeAlertUseCaseProvider)(alertId);
  final alert = result.when(
    success: (alert) => alert,
    failure: (failure) => throw Exception(failure.message),
  );
  ref.invalidate(openAlertsProvider);
  return alert;
});
