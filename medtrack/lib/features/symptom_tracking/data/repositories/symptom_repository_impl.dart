import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/symptom_log.dart';
import '../../domain/repositories/symptom_repository.dart';
import '../datasources/symptom_local_datasource.dart';
import '../datasources/symptom_remote_datasource.dart';
import '../models/symptom_log_model.dart';

class SymptomRepositoryImpl implements SymptomRepository {
  SymptomRepositoryImpl({
    required SymptomRemoteDataSource remote,
    required SymptomLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final SymptomRemoteDataSource _remote;
  final SymptomLocalDataSource _local;

  @override
  Future<Result<SymptomLog>> recordSymptom(SymptomLog log) async {
    final saved = await _local.insert(SymptomLogModel.fromEntity(log));
    try {
      await _remote.submitSymptomLog(saved);
    } catch (_) {
      // Local write already succeeded; background sync will retry.
    }
    return Success(saved);
  }

  @override
  Future<Result<List<SymptomLog>>> getHistory({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final remoteHistory =
          await _remote.getHistory(patientId: patientId, from: from, to: to);
      return Success(remoteHistory);
    } on DioException {
      final cached =
          await _local.readHistory(patientId: patientId, from: from, to: to);
      return Success(cached);
    } catch (_) {
      return const Error(ServerFailure());
    }
  }
}
