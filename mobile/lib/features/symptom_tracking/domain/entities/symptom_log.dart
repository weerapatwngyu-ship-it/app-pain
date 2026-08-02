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

  /// Set when this instance came back from the API (fetched, not being
  /// created) — null for a log the user is about to submit.
  final String? id;
  final DateTime? recordedAt;

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        if (painScore != null) 'painScore': painScore,
        if (category != null) 'category': category,
        if (customFields != null) 'customFields': customFields,
      };

  factory SymptomLog.fromJson(Map<String, dynamic> json) {
    return SymptomLog(
      id: json['id'] as String?,
      patientId: json['patientId'] as String,
      painScore: json['painScore'] as int?,
      category: json['category'] as String?,
      customFields: json['customFields'] as Map<String, dynamic>?,
      recordedAt:
          json['recordedAt'] != null ? DateTime.parse(json['recordedAt'] as String) : null,
    );
  }
}
