import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_screen.dart';
import '../data/doctor_repository.dart';
import '../domain/entities/doctor.dart';
import '../../../core/errors/friendly_error.dart';

/// Read-only for patients: the directory is maintained by an admin, and the
/// only thing a patient does here is start (or continue) a chat.
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({
    super.key,
    required this.doctor,
    required this.chatRepository,
    required this.doctorRepository,
    this.patientId,
  });

  final Doctor doctor;
  final ChatRepository chatRepository;

  /// Used only for the consultation total, which is counted in the database
  /// rather than carried on the listing.
  final DoctorRepository doctorRepository;

  /// Null when the viewer has no patient record (staff browsing the
  /// directory) — messaging needs a patient side, so the button is hidden.
  final String? patientId;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  bool _opening = false;
  int? _consultCount;

  Future<void> _openChat() async {
    final patientId = widget.patientId;
    if (patientId == null) return;

    setState(() => _opening = true);
    try {
      final conversation = await widget.chatRepository.openConversation(
        patientId: patientId,
        doctorId: widget.doctor.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversation.id,
            title: widget.doctor.name,
            subtitle: widget.doctor.specialty,
            repository: widget.chatRepository,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, whileDoing: 'เปิดแชทไม่สำเร็จ'))),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadConsultCount();
  }

  Future<void> _loadConsultCount() async {
    try {
      final count = await widget.doctorRepository.consultCount(widget.doctor.id);
      if (mounted) setState(() => _consultCount = count);
    } catch (_) {
      // Left off the page rather than shown as zero, which would read as a
      // claim that nobody has consulted them.
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final canChat = widget.patientId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      appBar: AppBar(
        title: const Text('ประวัติแพทย์'),
        backgroundColor: Colors.white,
      ),
      // The action sits on a bar of its own so it stays reachable however far
      // the profile scrolls — this is the one thing the page exists to do.
      bottomNavigationBar: canChat
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _opening ? null : _openChat,
                      icon: _opening
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      label: Text(_opening ? 'กำลังเปิด...' : 'ปรึกษาแพทย์ท่านนี้'),
                      style: FilledButton.styleFrom(
                        backgroundColor: OnboardingColors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _HeaderCard(doctor: doctor, consultCount: _consultCount),
          if (doctor.conditions.isNotEmpty)
            _Section(
              title: 'อาการที่รับปรึกษา',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final condition in doctor.conditions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(Icons.check_circle_outline,
                                size: 16, color: OnboardingColors.teal),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(condition,
                                style: const TextStyle(height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (doctor.bio != null && doctor.bio!.trim().isNotEmpty)
            _Section(
              title: 'ข้อมูลเพิ่มเติม',
              child: Text(doctor.bio!, style: const TextStyle(height: 1.6)),
            ),
          if (!canChat)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'บัญชีนี้ไม่มีข้อมูลผู้ป่วย จึงยังส่งข้อความไม่ได้',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFC0392B), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ข้อความในแอปไม่ใช่ช่องทางฉุกเฉิน — หากมีอาการรุนแรง โทร 1669',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.4, color: Color(0xFFC0392B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Identity block at the top of the profile: who they are, what they charge,
/// and how many people have consulted them.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.doctor, required this.consultCount});

  final Doctor doctor;
  final int? consultCount;

  @override
  Widget build(BuildContext context) {
    final photoUrl = doctor.photoUrl;
    final badge = doctor.languageBadge;
    final fee = doctor.feeText;
    final duration = doctor.durationText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OnboardingColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: OnboardingColors.teal,
                            child: const Icon(Icons.medical_services_outlined,
                                color: Colors.white, size: 34),
                          ),
                        )
                      : Container(
                          color: OnboardingColors.teal,
                          child: const Icon(Icons.medical_services_outlined,
                              color: Colors.white, size: 34),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            doctor.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (badge.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: OnboardingColors.border),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: OnboardingColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        doctor.specialty,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OnboardingColors.teal,
                        ),
                      ),
                    ),
                    if (doctor.credential != null) ...[
                      const SizedBox(height: 8),
                      _InfoLine(
                          icon: Icons.workspace_premium_outlined,
                          text: doctor.credential!),
                    ],
                    if (doctor.workplace != null) ...[
                      const SizedBox(height: 4),
                      _InfoLine(
                          icon: Icons.place_outlined, text: doctor.workplace!),
                    ],
                    if (consultCount != null && consultCount! > 0) ...[
                      const SizedBox(height: 4),
                      _InfoLine(
                          icon: Icons.forum_outlined,
                          text: '$consultCount คนเคยปรึกษา'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (fee != null || duration != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FAF8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (fee != null) ...[
                    const Text('ค่าปรึกษา',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: OnboardingColors.textMuted)),
                    const SizedBox(width: 8),
                    Text(
                      fee,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: OnboardingColors.teal,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (duration != null) ...[
                    const Icon(Icons.schedule,
                        size: 16, color: OnboardingColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      duration,
                      style: const TextStyle(
                          fontSize: 13, color: OnboardingColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: OnboardingColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: OnboardingColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled white block. Only built when it has content, so the profile of a
/// doctor whose details are not filled in is short rather than a run of empty
/// headings.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OnboardingColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
