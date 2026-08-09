/// One patient-to-patient thread, as returned by the `peer_threads()` RPC.
///
/// The counterpart is already resolved server-side: the RPC decides which of
/// the pair is "the other one" and returns only their name, so the app never
/// reads another patient's row to render this list.
class PeerThread {
  const PeerThread({
    required this.conversationId,
    required this.otherPatientId,
    required this.otherName,
    required this.lastMessageAt,
  });

  final String conversationId;
  final String otherPatientId;
  final String otherName;
  final DateTime lastMessageAt;

  factory PeerThread.fromRow(Map<String, dynamic> row) {
    return PeerThread(
      conversationId: row['conversation_id'] as String,
      otherPatientId: row['other_patient_id'] as String,
      otherName: (row['other_name'] as String?) ?? 'ผู้ใช้',
      lastMessageAt: DateTime.parse(row['last_message_at'] as String).toLocal(),
    );
  }
}

/// A person who may be messaged — name only, never anything clinical.
class PeerContact {
  const PeerContact({required this.patientId, required this.displayName});

  final String patientId;
  final String displayName;

  factory PeerContact.fromRow(Map<String, dynamic> row) {
    return PeerContact(
      patientId: row['patient_id'] as String,
      displayName: (row['display_name'] as String?) ?? 'ผู้ใช้',
    );
  }
}
