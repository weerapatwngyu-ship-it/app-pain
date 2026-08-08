class SymptomLog {
  const SymptomLog({
    required this.patientId,
    this.painScore,
    this.category,
    this.customFields,
    this.id,
    this.recordedAt,
  });

  final String patientId;
  final int? painScore;
  final String? category;
  final Map<String, dynamic>? customFields;

  /// Set when this instance came back from the database (fetched, not being
  /// created) — null for a log the user is about to submit.
  final String? id;
  final DateTime? recordedAt;

  Map<String, dynamic> toRow() => {
        'patient_id': patientId,
        if (painScore != null) 'pain_score': painScore,
        if (category != null) 'category': category,
        if (customFields != null) 'custom_fields': customFields,
      };

  factory SymptomLog.fromRow(Map<String, dynamic> row) {
    return SymptomLog(
      id: row['id'] as String?,
      patientId: row['patient_id'] as String,
      painScore: row['pain_score'] as int?,
      category: row['category'] as String?,
      customFields: row['custom_fields'] as Map<String, dynamic>?,
      recordedAt:
          row['recorded_at'] != null ? DateTime.parse(row['recorded_at'] as String) : null,
    );
  }
}
