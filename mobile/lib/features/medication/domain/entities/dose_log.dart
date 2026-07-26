enum DoseLogStatus { taken, skipped, snoozed, missed }

class DoseLog {
  const DoseLog({
    required this.scheduleId,
    required this.scheduledAt,
    required this.status,
    this.actionedAt,
  });

  final String scheduleId;
  final DateTime scheduledAt;
  final DateTime? actionedAt;
  final DoseLogStatus status;

  Map<String, dynamic> toJson() => {
        'scheduleId': scheduleId,
        'scheduledAt': scheduledAt.toIso8601String(),
        if (actionedAt != null) 'actionedAt': actionedAt!.toIso8601String(),
        'status': status.name,
      };
}
