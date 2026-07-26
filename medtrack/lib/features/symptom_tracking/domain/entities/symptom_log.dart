import 'package:equatable/equatable.dart';

class SymptomLog extends Equatable {
  const SymptomLog({
    required this.id,
    required this.patientId,
    required this.recordedAt,
    required this.painScore,
    this.mood,
    this.notes,
    this.customFields = const {},
  });

  final String id;
  final String patientId;
  final DateTime recordedAt;

  /// 0–10 pain scale, matching the architecture doc's data model.
  final int painScore;
  final String? mood;
  final String? notes;

  /// Extra fields defined per care plan (e.g. nausea level, rash present)
  /// without needing a schema migration for every condition type.
  final Map<String, dynamic> customFields;

  @override
  List<Object?> get props =>
      [id, patientId, recordedAt, painScore, mood, notes, customFields];
}
