import 'package:equatable/equatable.dart';

class VitalSign extends Equatable {
  const VitalSign({
    required this.id,
    required this.patientId,
    required this.recordedAt,
    this.heartRate,
    this.bloodPressure,
    this.temperatureCelsius,
  });

  final String id;
  final String patientId;
  final DateTime recordedAt;
  final int? heartRate;

  /// Stored as free text, e.g. "120/80", to match how it's read off a
  /// cuff rather than forcing systolic/diastolic into separate fields.
  final String? bloodPressure;
  final double? temperatureCelsius;

  @override
  List<Object?> get props =>
      [id, patientId, recordedAt, heartRate, bloodPressure, temperatureCelsius];
}
