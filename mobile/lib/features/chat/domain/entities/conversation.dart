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
    this.unread = false,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime lastMessageAt;

  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorPhotoUrl;
  final String? patientName;

  /// Something arrived that this reader has not opened yet.
  ///
  /// Worked out when the row is read, because which of the two read marks
  /// applies depends on which side is asking — see ChatRepository.
  final bool unread;

  factory Conversation.fromRow(Map<String, dynamic> row, {bool asDoctor = false}) {
    final doctor = row['doctors'] as Map<String, dynamic>?;
    final patient = row['patients'] as Map<String, dynamic>?;
    return Conversation(
      id: row['id'] as String,
      patientId: row['patient_id'] as String,
      doctorId: row['doctor_id'] as String,
      lastMessageAt: DateTime.parse(row['last_message_at'] as String).toLocal(),
      unread: _isUnread(row, asDoctor: asDoctor),
      doctorName: doctor?['name'] as String?,
      doctorSpecialty: doctor?['specialty'] as String?,
      doctorPhotoUrl: doctor?['photo_url'] as String?,
      patientName: patient?['name'] as String?,
    );
  }

  /// Compared here rather than in the query: PostgREST filters compare a
  /// column against a value, not against another column.
  static bool _isUnread(Map<String, dynamic> row, {required bool asDoctor}) {
    final last = DateTime.tryParse(row['last_message_at'] as String? ?? '');
    if (last == null) return false;
    final raw = row[asDoctor ? 'doctor_read_at' : 'patient_read_at'] as String?;
    // Never opened counts as unread, which is what a brand new thread is.
    if (raw == null) return true;
    final read = DateTime.tryParse(raw);
    return read == null || last.isAfter(read);
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
