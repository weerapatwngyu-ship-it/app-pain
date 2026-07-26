import '../../domain/entities/dose_log.dart';

class DoseLogModel extends DoseLog {
  const DoseLogModel({
    required super.id,
    required super.scheduleId,
    required super.scheduledAt,
    required super.status,
    super.actionedAt,
  });

  factory DoseLogModel.fromEntity(DoseLog log) => DoseLogModel(
        id: log.id,
        scheduleId: log.scheduleId,
        scheduledAt: log.scheduledAt,
        status: log.status,
        actionedAt: log.actionedAt,
      );

  factory DoseLogModel.fromDb(Map<String, dynamic> row) {
    return DoseLogModel(
      id: row['id'] as String,
      scheduleId: row['schedule_id'] as String,
      scheduledAt: DateTime.parse(row['scheduled_at'] as String),
      status: DoseStatus.values.byName(row['status'] as String),
      actionedAt: row['actioned_at'] == null
          ? null
          : DateTime.parse(row['actioned_at'] as String),
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'schedule_id': scheduleId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'actioned_at': actionedAt?.toIso8601String(),
        'status': status.name,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'schedule_id': scheduleId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'actioned_at': actionedAt?.toIso8601String(),
        'status': status.name,
      };
}
