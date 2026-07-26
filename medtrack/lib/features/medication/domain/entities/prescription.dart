import 'package:equatable/equatable.dart';

class Prescription extends Equatable {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
  });

  final String id;
  final String patientId;
  final String medicationName;
  final String dosage;

  /// Human-readable frequency, e.g. "วันละ 2 ครั้ง หลังอาหาร".
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props =>
      [id, patientId, medicationName, dosage, frequency, startDate, endDate];
}
