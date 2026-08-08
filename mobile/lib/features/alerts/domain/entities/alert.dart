enum AlertSeverity { normal, watch, critical }

enum AlertStatus { open, acknowledged }

class PatientAlert {
  const PatientAlert({
    required this.id,
    required this.severity,
    required this.status,
    this.message,
  });

  final String id;
  final AlertSeverity severity;
  final AlertStatus status;
  final String? message;

  factory PatientAlert.fromRow(Map<String, dynamic> row) {
    return PatientAlert(
      id: row['id'] as String,
      severity: AlertSeverity.values.byName(row['severity'] as String),
      status: AlertStatus.values.byName(row['status'] as String),
      message: row['message'] as String?,
    );
  }
}
