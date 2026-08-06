enum QuestionStatus {
  pending,
  answered,
  closed;

  static QuestionStatus fromRow(String? value) => switch (value) {
        'answered' => QuestionStatus.answered,
        'closed' => QuestionStatus.closed,
        _ => QuestionStatus.pending,
      };

  String get label => switch (this) {
        QuestionStatus.pending => 'รอแพทย์ตอบ',
        QuestionStatus.answered => 'ตอบแล้ว',
        QuestionStatus.closed => 'ปิดคำถามแล้ว',
      };
}

class HealthQuestion {
  const HealthQuestion({
    required this.id,
    required this.topicKey,
    required this.question,
    required this.status,
    required this.createdAt,
    this.answer,
    this.answeredAt,
  });

  final String id;
  final String topicKey;
  final String question;
  final QuestionStatus status;
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;

  factory HealthQuestion.fromRow(Map<String, dynamic> row) {
    return HealthQuestion(
      id: row['id'] as String,
      topicKey: row['topic_key'] as String,
      question: row['question'] as String,
      status: QuestionStatus.fromRow(row['status'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      answer: row['answer'] as String?,
      answeredAt: row['answered_at'] == null
          ? null
          : DateTime.parse(row['answered_at'] as String).toLocal(),
    );
  }
}
