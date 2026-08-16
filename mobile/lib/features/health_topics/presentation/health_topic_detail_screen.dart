import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../doctors/domain/entities/doctor.dart';
import '../../doctors/presentation/doctor_detail_screen.dart';
import '../data/health_question_repository.dart';
import '../domain/entities/health_question.dart';
import '../domain/entities/health_topic.dart';
import '../../../core/i18n/app_locale.dart';

class HealthTopicDetailScreen extends StatefulWidget {
  const HealthTopicDetailScreen({
    super.key,
    required this.topic,
    required this.patientId,
    required this.questionRepository,
    required this.doctorRepository,
    required this.chatRepository,
  });

  final HealthTopic topic;

  /// Null when the signed-in account has no patient record — reading is still
  /// allowed, asking is not.
  final String? patientId;
  final HealthQuestionRepository questionRepository;
  final DoctorRepository doctorRepository;
  final ChatRepository chatRepository;

  @override
  State<HealthTopicDetailScreen> createState() => _HealthTopicDetailScreenState();
}

class _HealthTopicDetailScreenState extends State<HealthTopicDetailScreen> {
  late Future<List<Doctor>> _doctorsFuture;
  Future<List<HealthQuestion>>? _questionsFuture;
  bool _onlyRelatedDoctors = true;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = widget.doctorRepository.fetchAll();
    _reloadQuestions();
  }

  void _reloadQuestions() {
    final patientId = widget.patientId;
    if (patientId == null) return;
    _questionsFuture =
        widget.questionRepository.fetchForTopic(patientId, widget.topic.key);
  }

  /// `doctors.specialty` is free text, so relatedness is a substring match on
  /// the topic's keywords rather than a foreign key.
  List<Doctor> _related(List<Doctor> all) {
    final keywords = widget.topic.specialtyKeywords;
    if (keywords.isEmpty) return all;
    final matches = all.where((doctor) {
      final specialty = doctor.specialty.toLowerCase();
      return keywords.any((k) => specialty.contains(k.toLowerCase()));
    }).toList();
    return matches;
  }

  Future<void> _openAskSheet() async {
    final patientId = widget.patientId;
    if (patientId == null) return;

    final asked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AskQuestionSheet(
        topic: widget.topic,
        patientId: patientId,
        repository: widget.questionRepository,
      ),
    );

    if (asked == true && mounted) {
      setState(_reloadQuestions);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('ส่งคำถามแล้ว — แพทย์จะตอบกลับในแอป', 'Question sent — a doctor will reply in the app'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            OnboardingHeader(
              icon: Icons.arrow_back,
              onIconTap: () => Navigator.of(context).pop(),
              title: topic.label,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(topic.icon, size: 36, color: OnboardingColors.teal),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      topic.summary,
                      style: const TextStyle(fontSize: 14, color: OnboardingColors.text),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Section(
              icon: Icons.checklist_rtl,
              title: t('อาการที่พบบ่อย', 'Common symptoms'),
              items: topic.commonSigns,
            ),
            _Section(
              icon: Icons.warning_amber_rounded,
              title: t('ควรพบแพทย์เมื่อไหร่', 'When to see a doctor'),
              items: topic.seeDoctorWhen,
              accent: const Color(0xFFC0392B),
            ),
            _Section(
              icon: Icons.favorite_outline,
              title: t('ดูแลตัวเองอย่างไร', 'Looking after yourself'),
              items: topic.selfCare,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E5),
                borderRadius: BorderRadius.circular(12),
              ),
              // Not const: healthTopicDisclaimer is translated, so it is a
              // getter now rather than a compile-time constant.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: Color(0xFFB26A00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      healthTopicDisclaimer,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFB26A00), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              t('ปรึกษาบุคลากร', 'Talk to a professional'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildDoctors(),
            const SizedBox(height: 28),
            Text(
              t('คำถามของฉันในหมวดนี้', 'My questions in this topic'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildQuestions(),
            const SizedBox(height: 20),
            if (widget.patientId != null)
              OnboardingPrimaryButton(
                label: t('ฝากคำถามถึงแพทย์', 'Ask a doctor'),
                onPressed: _openAskSheet,
              )
            else
              Text(
                t('ยังไม่มีข้อมูลผู้ป่วยในบัญชีนี้ จึงยังฝากคำถามไม่ได้', 'This account has no patient record yet, so questions cannot be sent'),
                style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctors() {
    return FutureBuilder<List<Doctor>>(
      future: _doctorsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final all = snapshot.data ?? const <Doctor>[];
        if (all.isEmpty) {
          return Text(
            t('ยังไม่มีรายชื่อบุคลากรในระบบ — ฝากคำถามไว้ได้ แพทย์จะตอบกลับภายหลัง', 'No professionals listed yet — you can still ask, and a doctor will reply later'),
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          );
        }

        final related = _related(all);
        // Falling back to the whole directory beats showing an empty list when
        // nobody's free-text specialty happens to match the topic keywords.
        final showing = (_onlyRelatedDoctors && related.isNotEmpty) ? related : all;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (related.isNotEmpty && related.length != all.length)
              Row(
                children: [
                  _FilterChip(
                    label: t('เกี่ยวกับ${widget.topic.label} (${related.length})', 'About ${widget.topic.label} (${related.length})'),
                    selected: _onlyRelatedDoctors,
                    onTap: () => setState(() => _onlyRelatedDoctors = true),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: t('ทั้งหมด (${all.length})', 'All (${all.length})'),
                    selected: !_onlyRelatedDoctors,
                    onTap: () => setState(() => _onlyRelatedDoctors = false),
                  ),
                ],
              ),
            if (related.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t('ยังไม่มีบุคลากรที่ระบุความเชี่ยวชาญตรงหมวดนี้ — แสดงรายชื่อทั้งหมดแทน', 'No one lists this speciality — showing everyone instead'),
                  style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
                ),
              ),
            const SizedBox(height: 8),
            ...showing.map(
              (doctor) => _DoctorRow(
                doctor: doctor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DoctorDetailScreen(
                      doctor: doctor,
                      chatRepository: widget.chatRepository,
                      doctorRepository: widget.doctorRepository,
                      patientId: widget.patientId,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestions() {
    if (widget.patientId == null) {
      return Text(
        t('เข้าสู่ระบบด้วยบัญชีผู้ป่วยเพื่อดูคำถามของคุณ', 'Sign in with a patient account to see your questions'),
        style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
      );
    }
    return FutureBuilder<List<HealthQuestion>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text(
            t('โหลดคำถามไม่สำเร็จ: ${snapshot.error}', 'Could not load questions: ${snapshot.error}'),
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error),
          );
        }
        final questions = snapshot.data ?? const <HealthQuestion>[];
        if (questions.isEmpty) {
          return Text(
            t('ยังไม่เคยถามในหมวดนี้', 'No questions in this topic yet'),
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          );
        }
        return Column(
          children: questions.map((q) => QuestionCard(question: q)).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.items,
    this.accent = OnboardingColors.teal,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (text) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: OnboardingColors.textMuted)),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? OnboardingColors.teal : Colors.white,
          border: Border.all(
            color: selected ? OnboardingColors.teal : OnboardingColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : OnboardingColors.text,
          ),
        ),
      ),
    );
  }
}

class _DoctorRow extends StatelessWidget {
  const _DoctorRow({required this.doctor, required this.onTap});

  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFDCEBE6),
              backgroundImage:
                  doctor.photoUrl != null ? NetworkImage(doctor.photoUrl!) : null,
              child: doctor.photoUrl == null
                  ? const Icon(Icons.person, color: OnboardingColors.teal)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    doctor.specialty,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OnboardingColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: OnboardingColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Shared with [MyQuestionsScreen] so a question reads the same everywhere.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question, this.showTopic = false});

  final HealthQuestion question;
  final bool showTopic;

  @override
  Widget build(BuildContext context) {
    final answered = question.status == QuestionStatus.answered;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: answered ? const Color(0xFFE3F3EF) : const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  question.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: answered ? OnboardingColors.teal : const Color(0xFFB26A00),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(question.createdAt),
                style: const TextStyle(fontSize: 11, color: OnboardingColors.textMuted),
              ),
            ],
          ),
          if (showTopic) ...[
            const SizedBox(height: 8),
            Text(
              healthTopicLabel(question.topicKey),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OnboardingColors.teal,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(question.question, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (question.answer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('คำตอบจากแพทย์', "Doctor's reply"),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OnboardingColors.teal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.answer!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------

class _AskQuestionSheet extends StatefulWidget {
  const _AskQuestionSheet({
    required this.topic,
    required this.patientId,
    required this.repository,
  });

  final HealthTopic topic;
  final String patientId;
  final HealthQuestionRepository repository;

  @override
  State<_AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<_AskQuestionSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.length < 10) {
      setState(() => _error = t('เขียนคำถามให้ละเอียดอีกนิด (อย่างน้อย 10 ตัวอักษร)', 'Add a little more detail (at least 10 characters)'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repository.ask(
        patientId: widget.patientId,
        topicKey: widget.topic.key,
        question: text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = t('ส่งคำถามไม่สำเร็จ: $e', 'Could not send the question: $e');
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('ถามเรื่อง${widget.topic.label}', 'Ask about ${widget.topic.label}'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            t('อธิบายอาการ ระยะเวลาที่เป็น และยาที่กินอยู่ จะช่วยให้แพทย์ตอบได้ตรงขึ้น', 'Describing the symptom, how long you have had it, and what you are taking helps the doctor answer'),
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: t('เช่น มีผื่นคันที่แขนมา 3 วัน กินยาแก้แพ้แล้วยังไม่ดีขึ้น', 'e.g. an itchy rash on my arm for 3 days, antihistamines have not helped'),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: OnboardingColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: OnboardingColors.border),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            t('หากเป็นเหตุฉุกเฉิน อย่ารอคำตอบในแอป — โทร 1669', 'In an emergency do not wait for a reply here — call 1669'),
            style: const TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
          ),
          const SizedBox(height: 16),
          OnboardingPrimaryButton(
            label: t('ส่งคำถาม', 'Send question'),
            loading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
