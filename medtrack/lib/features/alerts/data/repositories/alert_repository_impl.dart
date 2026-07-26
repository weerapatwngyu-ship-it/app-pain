import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_remote_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  const AlertRepositoryImpl(this._remote);

  final AlertRemoteDataSource _remote;

  @override
  Future<Result<List<Alert>>> getOpenAlerts() async {
    try {
      return Success(await _remote.getOpenAlerts());
    } on DioException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(ServerFailure());
    }
  }

  @override
  Future<Result<Alert>> acknowledge(String alertId) async {
    try {
      return Success(await _remote.acknowledge(alertId));
    } on DioException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(ServerFailure());
    }
  }
}
