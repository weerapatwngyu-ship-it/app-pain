import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/notification/notification_service.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/alerts/data/datasources/alert_remote_datasource.dart';
import '../../features/alerts/data/repositories/alert_repository_impl.dart';
import '../../features/alerts/domain/repositories/alert_repository.dart';
import '../../features/alerts/domain/usecases/acknowledge_alert_usecase.dart';
import '../../features/alerts/domain/usecases/get_open_alerts_usecase.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/medication/data/datasources/medication_local_datasource.dart';
import '../../features/medication/data/datasources/medication_remote_datasource.dart';
import '../../features/medication/data/repositories/medication_repository_impl.dart';
import '../../features/medication/domain/repositories/medication_repository.dart';
import '../../features/medication/domain/usecases/get_today_schedule_usecase.dart';
import '../../features/medication/domain/usecases/log_dose_usecase.dart';
import '../../features/symptom_tracking/data/datasources/symptom_local_datasource.dart';
import '../../features/symptom_tracking/data/datasources/symptom_remote_datasource.dart';
import '../../features/symptom_tracking/data/repositories/symptom_repository_impl.dart';
import '../../features/symptom_tracking/domain/repositories/symptom_repository.dart';
import '../../features/symptom_tracking/domain/usecases/get_symptom_trend_usecase.dart';
import '../../features/symptom_tracking/domain/usecases/record_symptom_usecase.dart';
import 'env.dart';

final GetIt getIt = GetIt.instance;

/// Wires the dependency graph once at startup: core services first
/// (some async, like opening the local DB), then each feature's
/// datasource → repository → use case chain. Call [configureDependencies]
/// in `main()` before `runApp`, and await `getIt.allReady()`.
Future<void> configureDependencies() async {
  getIt.registerLazySingleton<SecureStorage>(() => SecureStorage());
  getIt.registerSingletonAsync<LocalDatabase>(() => LocalDatabase.open());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());

  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: Env.apiBaseUrl, secureStorage: getIt()),
  );

  // Auth
  getIt.registerLazySingleton(() => AuthRemoteDataSource(getIt()));
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: getIt(), secureStorage: getIt()),
  );
  getIt.registerLazySingleton(() => LoginUseCase(getIt()));

  // Medication
  getIt.registerLazySingleton(() => MedicationRemoteDataSource(getIt()));
  getIt.registerSingletonWithDependencies<MedicationLocalDataSource>(
    () => MedicationLocalDataSource(getIt()),
    dependsOn: [LocalDatabase],
  );
  getIt.registerSingletonWithDependencies<MedicationRepository>(
    () => MedicationRepositoryImpl(remote: getIt(), local: getIt()),
    dependsOn: [MedicationLocalDataSource],
  );
  getIt.registerLazySingleton(() => GetTodayScheduleUseCase(getIt()));
  getIt.registerLazySingleton(() => LogDoseUseCase(getIt()));

  // Symptom tracking
  getIt.registerLazySingleton(() => SymptomRemoteDataSource(getIt()));
  getIt.registerSingletonWithDependencies<SymptomLocalDataSource>(
    () => SymptomLocalDataSource(getIt()),
    dependsOn: [LocalDatabase],
  );
  getIt.registerSingletonWithDependencies<SymptomRepository>(
    () => SymptomRepositoryImpl(remote: getIt(), local: getIt()),
    dependsOn: [SymptomLocalDataSource],
  );
  getIt.registerLazySingleton(() => RecordSymptomUseCase(getIt()));
  getIt.registerLazySingleton(() => GetSymptomTrendUseCase(getIt()));

  // Alerts
  getIt.registerLazySingleton(() => AlertRemoteDataSource(getIt()));
  getIt.registerLazySingleton<AlertRepository>(() => AlertRepositoryImpl(getIt()));
  getIt.registerLazySingleton(() => GetOpenAlertsUseCase(getIt()));
  getIt.registerLazySingleton(() => AcknowledgeAlertUseCase(getIt()));

  await getIt.allReady();
}
