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

  /// toUtc before serialising, both times.
  ///
  /// A local DateTime serialises with no offset at all ("2026-08-25T08:00:00"),
  /// and Postgres reads a bare timestamp as UTC — so an 08:00 dose in Bangkok
  /// landed in the database as 15:00 local. Every window and every displayed
  /// time built on these columns was seven hours out.
  Map<String, dynamic> toRow() => {
        'schedule_id': scheduleId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (actionedAt != null)
          'actioned_at': actionedAt!.toUtc().toIso8601String(),
        'status': status.name,
      };
}
