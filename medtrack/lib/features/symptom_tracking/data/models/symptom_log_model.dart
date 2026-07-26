import 'dart:convert';

import '../../domain/entities/symptom_log.dart';

class SymptomLogModel extends SymptomLog {
  const SymptomLogModel({
    required super.id,
    required super.patientId,
    required super.recordedAt,
    required super.painScore,
    super.mood,
    super.notes,
    super.customFields,
  });

  factory SymptomLogModel.fromEntity(SymptomLog log) => SymptomLogModel(
        id: log.id,
        patientId: log.patientId,
        recordedAt: log.recordedAt,
        painScore: log.painScore,
        mood: log.mood,
        notes: log.notes,
        customFields: log.customFields,
      );

  factory SymptomLogModel.fromJson(Map<String, dynamic> json) {
    return SymptomLogModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      painScore: json['pain_score'] as int,
      mood: json['mood'] as String?,
      notes: json['notes'] as String?,
      customFields: (json['custom_fields'] as Map<String, dynamic>?) ?? {},
    );
  }

  factory SymptomLogModel.fromDb(Map<String, dynamic> row) {
    return SymptomLogModel(
      id: row['id'] as String,
      patientId: row['patient_id'] as String,
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      painScore: row['pain_score'] as int,
      customFields: row['custom_fields'] == null
          ? {}
          : jsonDecode(row['custom_fields'] as String) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        'recorded_at': recordedAt.toIso8601String(),
        'pain_score': painScore,
        'mood': mood,
        'notes': notes,
        'custom_fields': customFields,
      };

  Map<String, dynamic> toDb() => {
        'id': id,
        'patient_id': patientId,
        'recorded_at': recordedAt.toIso8601String(),
        'pain_score': painScore,
        'custom_fields': jsonEncode(customFields),
      };
}
