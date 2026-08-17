import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_refs.dart';
import '../../chat/domain/entities/conversation.dart';
import '../../chat/domain/message_thread.dart';
import '../domain/entities/peer_thread.dart';

/// Patient-to-patient direct messages.
///
/// The thread list, the directory and opening a thread all go through RPCs
/// rather than table queries. That is not indirection for its own sake: the
/// `peer_conversations` table carries no INSERT policy at all, so
/// `open_peer_conversation()` is the only way a thread can be created, and it
/// re-derives the caller's own patient id server-side instead of trusting one
/// sent from here.
class PeerChatRepository implements MessageThread {
  /// Whether this patient has opted in. Nothing about peer chat works until
  /// they have — they are neither listed nor able to browse.
  Future<bool> isEnabled(String patientId) async {
    final row = await db
        .from('patients')
        .select('peer_chat_enabled')
        .eq('id', patientId)
        .maybeSingle();
    return (row?['peer_chat_enabled'] as bool?) ?? false;
  }

  Future<void> setEnabled({required String patientId, required bool enabled}) async {
    await db
        .from('patients')
        .update({'peer_chat_enabled': enabled})
        .eq('id', patientId);
  }

  /// Records that the caller has opened a peer thread.
  ///
  /// Through an RPC because the peer tables grant clients no UPDATE at all —
  /// mark_peer_read re-derives who is asking instead of trusting an id from
  /// here. Best-effort: an uncleared dot is not worth failing to open a chat.
  Future<void> markRead(String conversationId) async {
    try {
      await db.rpc('mark_peer_read', params: {'conversation': conversationId});
    } catch (_) {}
  }

  /// How many peer threads have something the caller has not opened.
  Future<int> unreadCount() async {
    final threads = await this.threads();
    return threads.where((thread) => thread.unread).length;
  }

  /// The caller's threads, newest activity first.
  Future<List<PeerThread>> threads() async {
    final rows = await db.rpc('peer_threads') as List<dynamic>;
    return rows
        .map((row) => PeerThread.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Opted-in patients other than the caller, optionally filtered by name.
  Future<List<PeerContact>> directory({String search = ''}) async {
    final rows = await db.rpc('peer_directory', params: {'search': search}) as List<dynamic>;
    return rows
        .map((row) => PeerContact.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Opens the thread with [otherPatientId], or returns the existing one.
  /// Throws if either side has peer chat switched off.
  Future<String> openConversation(String otherPatientId) async {
    final id = await db.rpc(
      'open_peer_conversation',
      params: {'target_patient_id': otherPatientId},
    );
    if (id == null) throw StateError('เปิดห้องแชทไม่สำเร็จ');
    return id as String;
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await db
        .from('peer_messages')
        .select()
        .eq('conversation_id', conversationId)
        // Oldest first, newest at the bottom — see the note in
        // ChatRepository.messages about order()'s default direction.
        .order('created_at', ascending: true);
    return rows.map<ChatMessage>(ChatMessage.fromRow).toList();
  }

  @override
  Future<void> send({required String conversationId, required String body}) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    // No follow-up write to keep the thread list sorted: a trigger on
    // peer_messages moves last_message_at, so there is nothing to fail here
    // and no UPDATE grant on the conversation for a client to abuse.
    await db.from('peer_messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'body': body,
    });
  }

  @override
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage message) onMessage,
  ) {
    final channel = db.channel('peer_messages:$conversationId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'peer_messages',
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
