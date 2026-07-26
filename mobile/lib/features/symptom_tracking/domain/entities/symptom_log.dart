class SymptomLog {
  const SymptomLog({
    required this.patientId,
    required this.painScore,
    this.customFields,
  });

  final String patientId;
  final int painScore;
  final Map<String, dynamic>? customFields;

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'painScore': painScore,
        if (customFields != null) 'customFields': customFields,
      };
}
