import 'package:equatable/equatable.dart';

enum AlertSeverity { normal, watch, critical }

enum AlertStatus { open, acknowledged }

class Alert extends Equatable {
  const Alert({
    required this.id,
    required this.patientId,
    required this.title,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String title;
  final AlertSeverity severity;
  final AlertStatus status;
  final DateTime createdAt;

  Alert copyWith({AlertStatus? status}) => Alert(
        id: id,
        patientId: patientId,
        title: title,
        severity: severity,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, patientId, title, severity, status, createdAt];
}
