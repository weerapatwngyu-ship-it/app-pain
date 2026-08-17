import 'package:flutter/material.dart';

import '../../../shared/widgets/unread_dot.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/presentation/chat_screen.dart';
import '../data/peer_chat_repository.dart';
import '../domain/entities/peer_thread.dart';
import 'peer_directory_screen.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

/// "คุยกับผู้ป่วยด้วยกัน" — the patient's own thread list, gated behind an
/// explicit opt-in.
///
/// The gate is the feature's safety story, so it is a screen and not a
/// setting buried elsewhere: until the patient turns this on they are invisible
/// to every other patient, and turning it off hides them again.
class PeerChatScreen extends StatefulWidget {
  const PeerChatScreen({
    super.key,
    required this.patientId,
    required this.repository,
  });

  final String patientId;
  final PeerChatRepository repository;

  @override
  State<PeerChatScreen> createState() => _PeerChatScreenState();
}

class _PeerChatScreenState extends State<PeerChatScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  List<PeerThread> _threads = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await widget.repository.isEnabled(widget.patientId);
      // Skip the thread query when switched off: the RPC would return nothing
      // anyway, and the empty state below is the one to show.
      final threads = enabled ? await widget.repository.threads() : <PeerThread>[];
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _threads = threads;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t('โหลดข้อมูลไม่สำเร็จ: $e', 'Could not load: $e');
        _loading = false;
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (value && !await _confirmOptIn()) return;

    setState(() => _saving = true);
    try {
      await widget.repository.setEnabled(patientId: widget.patientId, enabled: value);
      if (!mounted) return;
      setState(() {
        _enabled = value;
        _saving = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, whileDoing: t('บันทึกไม่สำเร็จ', 'Could not save')))),
      );
    }
  }

  Future<bool> _confirmOptIn() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('เปิดให้ผู้ป่วยคนอื่นคุยด้วย', 'Let other patients message me')),
        content: Text(
          t(
            'เมื่อเปิด ผู้ป่วยคนอื่นที่เปิดฟีเจอร์นี้จะเห็นชื่อของคุณ '
                'และส่งข้อความหาคุณได้\n\n'
                'ข้อมูลการรักษา ยา และอาการของคุณจะไม่ถูกแชร์\n\n'
                'ข้อความในนี้เป็นการคุยกันเองระหว่างผู้ป่วย '
                'ไม่ใช่คำแนะนำจากแพทย์ อย่าใช้แทนการปรึกษาแพทย์',
            'When this is on, other patients who also turned it on can see '
                'your name and message you.\n\n'
                'Your treatment, medication and symptoms are not shared.\n\n'
                'Messages here are between patients, not medical advice. Do '
                'not use it in place of seeing a doctor.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('เข้าใจแล้ว เปิดเลย', 'Got it, turn it on')),
          ),
        ],
      ),
    );
    return agreed == true;
  }

  Future<void> _openDirectory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PeerDirectoryScreen(repository: widget.repository),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openThread(PeerThread thread) async {
    // Read on the way in, like the doctor threads: the messages are on screen
    // now, so a dot that outlived opening them would be telling a lie.
    await widget.repository.markRead(thread.conversationId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: thread.conversationId,
          title: thread.otherName,
          subtitle: t('ผู้ป่วยด้วยกัน', 'Fellow patient'),
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(t('คุยกับผู้ป่วยด้วยกัน', 'Talk to other patients'))),
      body: _buildBody(),
      floatingActionButton: _enabled && !_loading
          ? FloatingActionButton.extended(
              onPressed: _openDirectory,
              backgroundColor: OnboardingColors.teal,
              icon: const Icon(Icons.person_search, color: Colors.white),
              label: Text(t('หาเพื่อนคุย', 'Find someone'), style: const TextStyle(color: Colors.white)),
            )
          : null,
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
                  setState(() => _loading = true);
                  _load();
                },
                child: Text(t('ลองอีกครั้ง', 'Try again')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildToggle(),
        const Divider(height: 1),
        Expanded(child: _buildThreads()),
      ],
    );
  }

  Widget _buildToggle() {
    return SwitchListTile(
      value: _enabled,
      onChanged: _saving ? null : _setEnabled,
      // No explicit thumb colour: the parameter for it was renamed
      // (activeColor -> activeThumbColor) across the Flutter versions this
      // pubspec allows, so the theme's colorScheme drives it instead.
      title: Text(t('เปิดให้ผู้ป่วยคนอื่นคุยด้วย', 'Let other patients message me')),
      subtitle: Text(
        _enabled
            ? t('ผู้ป่วยที่เปิดฟีเจอร์นี้เหมือนกันจะเห็นชื่อคุณ', 'Patients who turned this on can see your name')
            : t('ตอนนี้ไม่มีใครเห็นชื่อคุณ', 'Nobody can see your name right now'),
        style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
      ),
    );
  }

  Widget _buildThreads() {
    if (!_enabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t(
              'เปิดสวิตช์ด้านบนเพื่อเริ่มคุยกับผู้ป่วยคนอื่น\n\n'
                  'ข้อความที่นี่เป็นการคุยกันเองระหว่างผู้ป่วย\n'
                  'ไม่ใช่คำแนะนำจากแพทย์',
              'Turn on the switch above to start talking to other patients.\n\n'
                  'Messages here are between patients,\nnot medical advice.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: OnboardingColors.textMuted, height: 1.5),
          ),
        ),
      );
    }
    if (_threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t('ยังไม่มีแชท\nกด "หาเพื่อนคุย" เพื่อเริ่มคุยกับใครสักคน', 'No chats yet\nPress "Find someone" to start one'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: OnboardingColors.textMuted),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final thread = _threads[index];
          return ListTile(
            leading: UserAvatar(name: thread.otherName, radius: 20),
            title: Text(
              thread.otherName,
              style: TextStyle(
                fontWeight:
                    thread.unread ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              _formatWhen(thread.lastMessageAt),
              style: TextStyle(
                fontSize: 12,
                color: thread.unread
                    ? OnboardingColors.teal
                    : OnboardingColors.textMuted,
                fontWeight: thread.unread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (thread.unread) ...[
                  const UnreadDot(),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openThread(thread),
          );
        },
      ),
    );
  }

  static String _formatWhen(DateTime when) {
    final now = DateTime.now();
    final sameDay = when.year == now.year && when.month == now.month && when.day == now.day;
    final time =
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return sameDay ? time : '${when.day}/${when.month}/${when.year} $time';
  }
}
