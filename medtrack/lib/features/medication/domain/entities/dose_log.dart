import 'package:equatable/equatable.dart';

enum DoseStatus { taken, skipped, snoozed, missed }

class DoseLog extends Equatable {
  const DoseLog({
    required this.id,
    required this.scheduleId,
    required this.scheduledAt,
    required this.status,
    this.actionedAt,
  });

  final String id;
  final String scheduleId;
  final DateTime scheduledAt;
  final DateTime? actionedAt;
  final DoseStatus status;

  DoseLog copyWith({DoseStatus? status, DateTime? actionedAt}) {
    return DoseLog(
      id: id,
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
      status: status ?? this.status,
      actionedAt: actionedAt ?? this.actionedAt,
    );
  }

  @override
  List<Object?> get props => [id, scheduleId, scheduledAt, actionedAt, status];
}
