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

  factory PatientAlert.fromJson(Map<String, dynamic> json) {
    return PatientAlert(
      id: json['id'] as String,
      severity: AlertSeverity.values.byName(json['severity'] as String),
      status: AlertStatus.values.byName(json['status'] as String),
      message: json['message'] as String?,
    );
  }
}
