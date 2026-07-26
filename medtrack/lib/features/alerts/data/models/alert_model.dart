import '../../domain/entities/alert.dart';

class AlertModel extends Alert {
  const AlertModel({
    required super.id,
    required super.patientId,
    required super.title,
    required super.severity,
    required super.status,
    required super.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      title: json['title'] as String,
      severity: AlertSeverity.values.byName(json['severity'] as String),
      status: AlertStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
