import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/conversation.dart';
import '../domain/message_thread.dart';

class ChatRepository implements MessageThread {
  /// Threads for a patient, newest activity first, with the doctor joined in
  /// so the list can render without a second round trip.
  Future<List<Conversation>> conversationsForPatient(String patientId) async {
    final rows = await db
        .from('conversations')
        .select('*, doctors(name, specialty, photo_url)')
        .eq('patient_id', patientId)
        .order('last_message_at', ascending: false);
    return rows
        .map<Conversation>((row) => Conversation.fromRow(row))
        .toList();
  }

  /// Threads addressed to the signed-in doctor's listing.
  Future<List<Conversation>> conversationsForDoctor(String doctorId) async {
    final rows = await db
        .from('conversations')
        .select('*, patients(name)')
        .eq('doctor_id', doctorId)
        .order('last_message_at', ascending: false);
    return rows
        .map<Conversation>((row) => Conversation.fromRow(row, asDoctor: true))
        .toList();
  }

  /// The thread for this patient/doctor pair, creating it on first message.
  /// The table's unique(patient_id, doctor_id) makes reopening a chat continue
  /// the existing one rather than forking a second thread.
  Future<Conversation> openConversation({
    required String patientId,
    required String doctorId,
  }) async {
    final existing = await db
        .from('conversations')
        .select('*, doctors(name, specialty, photo_url)')
        .eq('patient_id', patientId)
        .eq('doctor_id', doctorId)
        .maybeSingle();
    if (existing != null) return Conversation.fromRow(existing);

    await db.from('conversations').insert({
      'patient_id': patientId,
      'doctor_id': doctorId,
    });
    // Re-read rather than using the insert's return, so the joined doctor
    // fields come back the same way they do on the list screen.
    final created = await db
        .from('conversations')
        .select('*, doctors(name, specialty, photo_url)')
        .eq('patient_id', patientId)
        .eq('doctor_id', doctorId)
        .single();
    return Conversation.fromRow(created);
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        // ascending explicitly: postgrest-dart's order() defaults to
        // DESCENDING, which put the newest message at the top of the thread
        // and read as a scrambled conversation.
        .order('created_at', ascending: true);
    return rows.map<ChatMessage>(ChatMessage.fromRow).toList();
  }

  @override
  Future<void> send({required String conversationId, required String body}) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    // No follow-up update here: touch_conversation() in the schema bumps
    // last_message_at and marks the thread read for the sender, in the same
    // transaction as the insert. Doing it from the client was best-effort, and
    // a bump that failed now costs more than sort order — unread is read off
    // the same column.
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'body': body,
    });
  }

  /// Records that this side has just opened the thread.
  ///
  /// Best-effort on purpose: failing to clear a badge is a cosmetic problem,
  /// and throwing here would break opening a conversation over it.
  Future<void> markRead(String conversationId, {required bool asDoctor}) async {
    try {
      await db
          .from('conversations')
          .update({
            (asDoctor ? 'doctor_read_at' : 'patient_read_at'):
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (_) {}
  }

  /// How many of this patient's doctor threads have something unopened.
  ///
  /// Two timestamps per row rather than the whole thread: this runs to draw a
  /// dot, and the names and photos the list needs are not wanted here.
  Future<int> unreadForPatient(String patientId) async {
    final rows = await db
        .from('conversations')
        .select('last_message_at, patient_read_at')
        .eq('patient_id', patientId);
    return _countUnread(rows, 'patient_read_at');
  }

  /// The same count for the doctor's inbox.
  Future<int> unreadForDoctor(String doctorId) async {
    final rows = await db
        .from('conversations')
        .select('last_message_at, doctor_read_at')
        .eq('doctor_id', doctorId);
    return _countUnread(rows, 'doctor_read_at');
  }

  static int _countUnread(List<Map<String, dynamic>> rows, String readColumn) {
    var count = 0;
    for (final row in rows) {
      final last = DateTime.tryParse(row['last_message_at'] as String? ?? '');
      if (last == null) continue;
      final raw = row[readColumn] as String?;
      // Never opened is unread, which is what a thread someone else started is.
      if (raw == null) {
        count++;
        continue;
      }
      final read = DateTime.tryParse(raw);
      if (read == null || last.isAfter(read)) count++;
    }
    return count;
  }

  /// Live updates for an open thread. Postgres changes arrive over Supabase
  /// Realtime, so a reply lands without the reader pulling to refresh.
  @override
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage message) onMessage,
  ) {
    final channel = db.channel('messages:$conversationId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) => onMessage(ChatMessage.fromRow(payload.newRecord)),
      );
    return channel..subscribe();
  }
}
