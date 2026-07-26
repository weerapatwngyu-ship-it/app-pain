import '../../domain/entities/dose_schedule.dart';

class DoseScheduleModel extends DoseSchedule {
  const DoseScheduleModel({
    required super.id,
    required super.prescriptionId,
    required super.medicationName,
    required super.dosage,
    required super.scheduledTime,
    super.isPrn,
  });

  factory DoseScheduleModel.fromJson(Map<String, dynamic> json) {
    return DoseScheduleModel(
      id: json['id'] as String,
      prescriptionId: json['prescription_id'] as String,
      medicationName: json['medication_name'] as String,
      dosage: json['dosage'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      isPrn: json['is_prn'] as bool? ?? false,
    );
  }

  factory DoseScheduleModel.fromDb(Map<String, dynamic> row) {
    return DoseScheduleModel(
      id: row['id'] as String,
      prescriptionId: row['prescription_id'] as String,
      medicationName: row['medication_name'] as String,
      dosage: row['dosage'] as String,
      scheduledTime: DateTime.parse(row['scheduled_time'] as String),
      isPrn: (row['is_prn'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'prescription_id': prescriptionId,
        'medication_name': medicationName,
        'dosage': dosage,
        'scheduled_time': scheduledTime.toIso8601String(),
        'is_prn': isPrn ? 1 : 0,
      };
}
