import 'package:equatable/equatable.dart';

class DoseSchedule extends Equatable {
  const DoseSchedule({
    required this.id,
    required this.prescriptionId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledTime,
    this.isPrn = false,
  });

  final String id;
  final String prescriptionId;
  final String medicationName;
  final String dosage;
  final DateTime scheduledTime;

  /// "Pro re nata" — taken as needed rather than at a fixed time.
  final bool isPrn;

  @override
  List<Object?> get props =>
      [id, prescriptionId, medicationName, dosage, scheduledTime, isPrn];
}
