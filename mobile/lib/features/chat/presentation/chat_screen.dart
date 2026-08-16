import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_refs.dart';
import '../../../shared/format/thai_date.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/conversation.dart';
import '../domain/message_thread.dart';
import '../../../core/errors/friendly_error.dart';

/// One thread, used by both sides — a message renders the same whether the
/// reader is the patient or the doctor; only which bubble is "mine" differs.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.repository,
    this.subtitle,
  });

  final String conversationId;
  final String title;
  final String? subtitle;
  final MessageThread repository;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _channel;

  String? get _myId => currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = widget.repository.subscribeToMessages(widget.conversationId, _onIncoming);
  }

  @override
  void dispose() {
    // Unsubscribing matters: the channel outlives the widget otherwise and
    // keeps pushing into a disposed State.
    if (_channel != null) db.removeChannel(_channel!);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onIncoming(ChatMessage message) {
    if (!mounted) return;
    // The sender already appended locally; realtime echoes it back.
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages = [..._messages, message]);
    _scrollToBottom();
  }

  Future<void> _load() async {
    try {
      final messages = await widget.repository.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อความไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  /// Lands on the newest message, which is the bottom of the list.
  ///
  /// Twice, a frame apart: a ListView.builder only lays out what is visible,
  /// so the first maxScrollExtent it reports is an estimate of a thread it has
  /// not measured yet. Jumping once leaves a long conversation a little short
  /// of the end — near enough to look right and wrong exactly when it matters,
  /// on the message the reader opened the thread for.
  void _scrollToBottom() {
    void jump() {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await widget.repository.send(conversationId: widget.conversationId, body: text);
      if (!mounted) return;
      _controller.clear();
      // Realtime will deliver the row; reloading keeps the thread correct even
      // if the socket dropped.
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, whileDoing: 'ส่งข้อความไม่สำเร็จ'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 17)),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'ยังไม่มีข้อความ\nพิมพ์ข้อความแรกได้เลย',
            textAlign: TextAlign.center,
            style: TextStyle(color: OnboardingColors.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        // A day divider above the first message of each day. Without it a
        // thread reads as one run of clock times, so yesterday's 20:14 sitting
        // above today's 13:58 looks like the messages are out of order.
        final previous = index == 0 ? null : _messages[index - 1];
        final newDay = previous == null ||
            !_sameDay(previous.createdAt, message.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) _DayDivider(day: message.createdAt),
            _Bubble(message: message, isMine: message.senderId == _myId),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: OnboardingColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: OnboardingColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: OnboardingColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: OnboardingColors.teal),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "วันนี้" / "เมื่อวาน" / "15 ส.ค. 2568", centred between days.
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _label(day),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: OnboardingColors.textMuted,
          ),
        ),
      ),
    );
  }

  /// Named days for the two the reader can place without thinking; a date for
  /// everything older, since "3 วันที่แล้ว" makes them do the arithmetic.
  static String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    final difference = today.difference(that).inDays;
    if (difference == 0) return 'วันนี้';
    if (difference == 1) return 'เมื่อวาน';
    return 'วัน${thaiWeekdays[that.weekday - 1]} ${thaiDate(that)}';
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? OnboardingColors.teal : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isMine ? Colors.white : OnboardingColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.white70 : OnboardingColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
