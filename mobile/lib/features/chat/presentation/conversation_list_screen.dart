import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/chat_repository.dart';
import '../domain/entities/conversation.dart';
import 'chat_screen.dart';
import '../../../core/i18n/app_locale.dart';

/// Thread list for either side. [isDoctorView] only picks which counterpart
/// name to show — the underlying rows and access rules are the same.
class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({
    super.key,
    required this.repository,
    required this.ownerId,
    required this.isDoctorView,
    this.showBackButton = true,
  });

  final ChatRepository repository;

  /// patientId for a patient, doctorId for a doctor.
  final String ownerId;
  final bool isDoctorView;
  final bool showBackButton;

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late Future<List<Conversation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Conversation>> _fetch() => widget.isDoctorView
      ? widget.repository.conversationsForDoctor(widget.ownerId)
      : widget.repository.conversationsForPatient(widget.ownerId);

  Future<void> _reload() async {
    setState(() => _future = _fetch());
    await _future;
  }

  Future<void> _open(Conversation conversation) async {
    final title = widget.isDoctorView
        ? (conversation.patientName ?? t('ผู้ป่วย', 'Patient'))
        : (conversation.doctorName ?? t('แพทย์', 'Doctor'));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          title: title,
          subtitle: widget.isDoctorView ? null : conversation.doctorSpecialty,
          repository: widget.repository,
        ),
      ),
    );
    // Coming back from a thread, its position in the list may have changed.
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(widget.isDoctorView ? t('ข้อความจากผู้ป่วย', 'Patient messages') : t('ข้อความของฉัน', 'My messages')),
      ),
      body: FutureBuilder<List<Conversation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('โหลดข้อความไม่สำเร็จ: ${snapshot.error}', 'Could not load messages: ${snapshot.error}'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _reload, child: Text(t('ลองอีกครั้ง', 'Try again'))),
                  ],
                ),
              ),
            );
          }
          final conversations = snapshot.data ?? const <Conversation>[];
          if (conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        widget.isDoctorView
                            ? t('ยังไม่มีผู้ป่วยส่งข้อความมา', 'No patients have messaged you yet')
                            : t('ยังไม่มีการสนทนา\nเลือกแพทย์จาก "ปรึกษาแพทย์" เพื่อเริ่มคุย', 'No conversations yet\nPick a doctor under "Talk to a doctor" to start'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OnboardingColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(
                color: OnboardingColors.border,
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final title = widget.isDoctorView
                    ? (conversation.patientName ?? t('ผู้ป่วย', 'Patient'))
                    : (conversation.doctorName ?? t('แพทย์', 'Doctor'));
                final photoUrl =
                    widget.isDoctorView ? null : conversation.doctorPhotoUrl;
                return ListTile(
                  onTap: () => _open(conversation),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: OnboardingColors.teal,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Icon(
                            widget.isDoctorView
                                ? Icons.person
                                : Icons.medical_services_outlined,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    widget.isDoctorView
                        ? _formatWhen(conversation.lastMessageAt)
                        : (conversation.doctorSpecialty ?? ''),
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Text(
                    _formatWhen(conversation.lastMessageAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: OnboardingColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static String _formatWhen(DateTime d) {
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}/${d.year}';
  }
}
