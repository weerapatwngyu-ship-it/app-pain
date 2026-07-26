import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/dose_schedule.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_local_datasource.dart';
import '../datasources/medication_remote_datasource.dart';
import '../models/dose_log_model.dart';
import '../models/dose_schedule_model.dart';

/// Offline-first: reads/writes hit the local store first, then try to
/// reach the API. A network failure here is not fatal — the caller
/// still gets a [Success] built from local data, per the doc's offline
/// & sync strategy.
class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required MedicationRemoteDataSource remote,
    required MedicationLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final MedicationRemoteDataSource _remote;
  final MedicationLocalDataSource _local;

  @override
  Future<Result<List<DoseSchedule>>> getTodaySchedule(String patientId) async {
    try {
      final remoteSchedule = await _remote.getTodaySchedule(patientId);
      await _local.cacheSchedule(remoteSchedule);
      return Success(remoteSchedule);
    } on DioException {
      final cached = await _local.readCachedSchedule();
      if (cached.isEmpty) return const Error(NetworkFailure());
      return Success(cached);
    } catch (_) {
      return const Error(ServerFailure());
    }
  }

  @override
  Future<Result<DoseLog>> logDose({
    required String scheduleId,
    required DateTime scheduledAt,
    required DoseStatus status,
  }) async {
    final draft = DoseLogModel(
      id: '',
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
      status: status,
      actionedAt: DateTime.now(),
    );

    final saved = await _local.insertDoseLog(draft);

    // Best-effort immediate sync; sync_queue entry means a background
    // worker will retry this later regardless of the outcome here.
    try {
      await _remote.submitDoseLog(saved);
    } catch (_) {
      // Swallowed intentionally — already durable in sync_queue.
    }

    return Success(saved);
  }

  @override
  Future<Result<double>> getAdherenceRate({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rate = await _remote.getAdherenceRate(
        patientId: patientId,
        from: from,
        to: to,
      );
      return Success(rate);
    } on DioException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(ServerFailure());
    }
  }
}
