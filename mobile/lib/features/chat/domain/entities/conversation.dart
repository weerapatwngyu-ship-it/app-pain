/// One ongoing thread between a patient and a specific doctor.
///
/// The counterpart fields are filled from the joined row, and which one is
/// populated depends on who is reading: a patient's thread list needs the
/// doctor's name, a doctor's list needs the patient's.
class Conversation {
  const Conversation({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.lastMessageAt,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorPhotoUrl,
    this.patientName,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime lastMessageAt;

  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorPhotoUrl;
  final String? patientName;

  factory Conversation.fromRow(Map<String, dynamic> row) {
    final doctor = row['doctors'] as Map<String, dynamic>?;
    final patient = row['patients'] as Map<String, dynamic>?;
    return Conversation(
      id: row['id'] as String,
      patientId: row['patient_id'] as String,
      doctorId: row['doctor_id'] as String,
      lastMessageAt: DateTime.parse(row['last_message_at'] as String).toLocal(),
      doctorName: doctor?['name'] as String?,
      doctorSpecialty: doctor?['specialty'] as String?,
      doctorPhotoUrl: doctor?['photo_url'] as String?,
      patientName: patient?['name'] as String?,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
