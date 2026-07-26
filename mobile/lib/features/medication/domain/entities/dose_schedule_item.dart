class DoseScheduleItem {
  const DoseScheduleItem({
    required this.scheduleId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledTime,
    required this.isPrn,
  });

  final String scheduleId;
  final String medicationName;
  final String dosage;
  final String scheduledTime;
  final bool isPrn;

  factory DoseScheduleItem.fromJson(Map<String, dynamic> json) {
    return DoseScheduleItem(
      scheduleId: json['scheduleId'] as String,
      medicationName: json['medicationName'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String,
      isPrn: json['isPrn'] as bool? ?? false,
    );
  }
}
