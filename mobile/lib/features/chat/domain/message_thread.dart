import 'package:supabase_flutter/supabase_flutter.dart';

import 'entities/conversation.dart';

/// What [ChatScreen] needs from whichever repository owns a thread.
///
/// A doctor thread and a patient-to-patient thread live in different tables
/// with different access rules, but they read and post identically — so the
/// chat UI is written against this instead of against one repository, and
/// there is a single bubble/composer implementation rather than two that
/// drift apart.
abstract class MessageThread {
  Future<List<ChatMessage>> messages(String conversationId);

  Future<void> send({required String conversationId, required String body});

  /// Live INSERTs for an open thread. The caller owns the returned channel
  /// and must remove it when the screen goes away.
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage message) onMessage,
  );
}
