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
    return rows.map<Conversation>(Conversation.fromRow).toList();
  }

  /// Threads addressed to the signed-in doctor's listing.
  Future<List<Conversation>> conversationsForDoctor(String doctorId) async {
    final rows = await db
        .from('conversations')
        .select('*, patients(name)')
        .eq('doctor_id', doctorId)
        .order('last_message_at', ascending: false);
    return rows.map<Conversation>(Conversation.fromRow).toList();
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
        .order('created_at');
    return rows.map<ChatMessage>(ChatMessage.fromRow).toList();
  }

  @override
  Future<void> send({required String conversationId, required String body}) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'body': body,
    });
    // Keeps the thread lists sorted by activity. Best-effort: the message is
    // already saved, and a stale sort order is not worth failing the send.
    try {
      await db
          .from('conversations')
          .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);
    } catch (_) {}
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
