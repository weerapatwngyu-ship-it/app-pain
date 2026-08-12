import 'package:flutter/material.dart';

import '../../../shared/widgets/avatar_picker.dart';
import '../../profile/data/patient_profile_repository.dart';
import '../data/medication_list_repository.dart';
import 'medication_list_screen.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../doctors/domain/entities/doctor.dart';
import '../../doctors/presentation/doctor_detail_screen.dart';
import '../../chat/data/chat_repository.dart';
import '../../doctors/presentation/doctor_list_screen.dart';
import '../../health_topics/data/health_question_repository.dart';
import '../../health_topics/domain/entities/health_topic.dart';
import '../../health_topics/presentation/health_topics_screen.dart';
import '../../symptom_tracking/domain/entities/symptom_category.dart';
import '../../symptom_tracking/domain/symptom_repository.dart';
import '../../symptom_tracking/presentation/symptom_category_logs_screen.dart';
import '../domain/entities/dose_log.dart';
import '../domain/entities/dose_schedule_item.dart';
import '../domain/medication_repository.dart';
import '../domain/usecases/log_dose_usecase.dart';

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({
    super.key,
    required this.refreshToken,
    required this.user,
    required this.patientId,
    required this.medicationRepository,
    required this.logDoseUseCase,
    required this.symptomRepository,
    required this.authRepository,
    required this.doctorRepository,
    required this.healthQuestionRepository,
    required this.chatRepository,
    required this.medicationListRepository,
    required this.patientProfileRepository,
    required this.onUserUpdated,
  });

  /// Changes when the shell wants this screen to re-read data it caches —
  /// the tabs sit in an IndexedStack, so initState runs only once.
  final int refreshToken;

  final AppUser user;
  final String patientId;
  final MedicationRepository medicationRepository;
  final LogDoseUseCase logDoseUseCase;
  final SymptomRepository symptomRepository;
  final AuthRepository authRepository;
  final DoctorRepository doctorRepository;
  final HealthQuestionRepository healthQuestionRepository;
  final ChatRepository chatRepository;
  final MedicationListRepository medicationListRepository;
  final PatientProfileRepository patientProfileRepository;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  late Future<List<DoseScheduleItem>> _scheduleFuture;
  late Future<Map<String, int>> _categoryCountsFuture;
  late Future<List<Doctor>> _doctorsFuture;

  /// Doses logged (taken or skipped) during this app session — the backend
  /// doesn't return today's already-logged status alongside the schedule,
  /// so this tracks only what's been actioned since the screen loaded, not
  /// history from a prior session.
  final Set<String> _actionedScheduleIds = {};

  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = widget.medicationRepository.todaySchedule(widget.patientId);
    _categoryCountsFuture = widget.symptomRepository.categoryCounts(widget.patientId);
    _doctorsFuture = widget.doctorRepository.fetchAll();
  }

  @override
  void didUpdateWidget(TodayScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _reloadDoctors();
  }

  void _reloadDoctors() {
    setState(() => _doctorsFuture = widget.doctorRepository.fetchAll());
  }

  void _reloadSchedule() {
    setState(() {
      _scheduleFuture = widget.medicationRepository.todaySchedule(widget.patientId);
      // Doses actioned against the old schedule no longer describe the new
      // one, and a stale id here would grey out an unrelated row.
      _actionedScheduleIds.clear();
    });
  }

  void _openHealthTopics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthTopicsScreen(
          patientId: widget.patientId,
          questionRepository: widget.healthQuestionRepository,
          doctorRepository: widget.doctorRepository,
          chatRepository: widget.chatRepository,
        ),
      ),
    );
  }

  Future<void> _openDoctorList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorListScreen(
          repository: widget.doctorRepository,
          chatRepository: widget.chatRepository,
          patientId: widget.patientId,
        ),
      ),
    );
    _reloadDoctors();
  }

  Future<void> _openDoctor(Doctor doctor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorDetailScreen(
          doctor: doctor,
          chatRepository: widget.chatRepository,
          patientId: widget.patientId,
        ),
      ),
    );
    _reloadDoctors();
  }

  void _openCategory(String? category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SymptomCategoryLogsScreen(
          patientId: widget.patientId,
          repository: widget.symptomRepository,
          category: category,
        ),
      ),
    );
  }

  Future<void> _logDose(DoseScheduleItem item, DoseLogStatus status) async {
    await widget.logDoseUseCase(DoseLog(
      scheduleId: item.scheduleId,
      scheduledAt: DateTime.now(),
      actionedAt: DateTime.now(),
      status: status,
    ));
    if (!mounted) return;
    setState(() => _actionedScheduleIds.add(item.scheduleId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกแล้ว: ${item.medicationName}')),
    );
  }

  /// Opens the medication list, then refreshes today's schedule — adding a
  /// medication with a time for later today should show up on return.
  Future<void> _openMedicationList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationListScreen(
          patientId: widget.patientId,
          repository: widget.medicationListRepository,
          profileRepository: widget.patientProfileRepository,
        ),
      ),
    );
    if (mounted) _reloadSchedule();
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final updated = await pickAndUploadAvatar(
        context: context,
        authRepository: widget.authRepository,
      );
      if (updated != null) widget.onUserUpdated(updated);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'สวัสดีตอนดึก';
    if (hour < 12) return 'สวัสดีตอนเช้า';
    if (hour < 18) return 'สวัสดีตอนบ่าย';
    return 'สวัสดีตอนเย็น';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<List<DoseScheduleItem>>(
          future: _scheduleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('โหลดตารางยาไม่สำเร็จ'));
            }
            final items = snapshot.data ?? [];
            final doneCount = items
                .where((item) => _actionedScheduleIds.contains(item.scheduleId))
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _Header(
                  greeting: _greeting,
                  name: widget.user.name,
                  avatarUrl: widget.user.avatarUrl != null
                      ? widget.user.avatarUrl!
                      : null,
                  uploadingAvatar: _uploadingAvatar,
                  onAvatarTap: _pickAndUploadAvatar,
                ),
                const SizedBox(height: 20),
                _SummaryCard(
                  total: items.length,
                  done: doneCount,
                  onTap: _openMedicationList,
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'ตารางยาวันนี้',
                  actionLabel: 'ยาของฉัน',
                  actionIcon: Icons.medication_outlined,
                  onAction: _openMedicationList,
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  // An empty schedule used to be a dead end: nothing in the app
                  // could add a medication, so this said "none today" forever.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Text('ไม่มีรายการยาวันนี้'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openMedicationList,
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มยาที่กินอยู่'),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map((item) => _DoseTile(
                        item: item,
                        actioned: _actionedScheduleIds.contains(item.scheduleId),
                        onLog: (status) => _logDose(item, status),
                      )),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'ปรึกษาแพทย์',
                  actionLabel: 'ดูทั้งหมด',
                  onAction: _openDoctorList,
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Doctor>>(
                  future: _doctorsFuture,
                  builder: (context, snapshot) {
                    final doctors = snapshot.data ?? const <Doctor>[];
                    // No "add doctor" affordance: the directory is maintained
                    // by an admin, so an empty row means nobody has been
                    // approved yet — not that the patient should add someone.
                    if (doctors.isEmpty) {
                      return const SizedBox(
                        height: 72,
                        child: Center(
                          child: Text(
                            'ยังไม่มีแพทย์ในระบบ',
                            style: TextStyle(
                              fontSize: 13,
                              color: OnboardingColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 132,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: doctors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final doctor = doctors[index];
                          return _DoctorTile(
                            doctor: doctor,
                            onTap: () => _openDoctor(doctor),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'คลินิกออนไลน์',
                  actionLabel: 'ดูทั้งหมด',
                  onAction: _openHealthTopics,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: healthTopics.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final topic = healthTopics[index];
                      return _HealthTopicTile(
                        topic: topic,
                        onTap: () => openHealthTopic(
                          context,
                          topic: topic,
                          patientId: widget.patientId,
                          questionRepository: widget.healthQuestionRepository,
                          doctorRepository: widget.doctorRepository,
                          chatRepository: widget.chatRepository,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'หมวดอาการ',
                  actionLabel: 'ดูทั้งหมด',
                  onAction: () => _openCategory(null),
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, int>>(
                  future: _categoryCountsFuture,
                  builder: (context, snapshot) {
                    final counts = snapshot.data ?? const {};
                    return SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: symptomCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final category = symptomCategories[index];
                          return _CategoryTile(
                            category: category,
                            count: counts[category.key] ?? 0,
                            onTap: () => _openCategory(category.key),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.uploadingAvatar,
    required this.onAvatarTap,
  });

  final String greeting;
  final String name;
  final String? avatarUrl;
  final bool uploadingAvatar;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          name: name,
          avatarUrl: avatarUrl,
          radius: 24,
          loading: uploadingAvatar,
          onTap: onAvatarTap,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13)),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor, required this.onTap});

  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = doctor.photoUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: OnboardingColors.teal,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.medical_services_outlined, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              doctor.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              doctor.specialty,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: OnboardingColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular, badge-free counterpart to [_CategoryTile]: a health topic is a
/// subject to read about, so there is no per-user count to show on it.
class _HealthTopicTile extends StatelessWidget {
  const _HealthTopicTile({required this.topic, required this.onTap});

  final HealthTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5F3),
                shape: BoxShape.circle,
              ),
              child: Icon(topic.icon, color: OnboardingColors.teal, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              topic.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.onTap});

  final SymptomCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(category.icon, color: OnboardingColors.teal, size: 26),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: OnboardingColors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.done,
    required this.onTap,
  });

  final int total;
  final int done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    // The first thing on the screen, and on a new account it reads "no
    // medication today" — so it is also the first place someone will press
    // to do something about that.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: OnboardingColors.teal,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ยาวันนี้',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'ไม่มีรายการยาวันนี้'
                  : 'บันทึกแล้ว $done จาก $total รายการ',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  total == 0 ? 'เพิ่มยาที่กินอยู่' : 'ดูยาทั้งหมดของฉัน',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One heading style for every section on this screen.
///
/// The four headings were four copies of the same twelve lines, which is how
/// they drifted apart — one used an icon, the others a chevron, and the gap
/// above each differed. Written once, they stay level with each other.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: OnboardingColors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actionIcon != null) ...[
                Icon(actionIcon, size: 17),
                const SizedBox(width: 4),
              ],
              Text(actionLabel, style: const TextStyle(fontSize: 14)),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.item, required this.actioned, required this.onLog});

  final DoseScheduleItem item;
  final bool actioned;
  final ValueChanged<DoseLogStatus> onLog;

  /// Roughly which part of the day a dose falls in. Printed under the clock
  /// time because "08:00" is precise but "เช้า" is what someone is actually
  /// looking for when they glance at the list.
  String get _partOfDay {
    final hour = int.tryParse(item.scheduledTime.split(':').first) ?? 0;
    // Before 05:00 is still the night before, not the morning — a 02:00 dose
    // labelled "เช้า" would send someone looking for it at breakfast.
    if (hour < 5) return 'กลางคืน';
    if (hour < 11) return 'เช้า';
    if (hour < 15) return 'กลางวัน';
    if (hour < 19) return 'เย็น';
    return 'ก่อนนอน';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: actioned ? const Color(0xFFD8ECE8) : OnboardingColors.border,
        ),
        borderRadius: BorderRadius.circular(16),
        color: actioned ? const Color(0xFFF3FAF8) : Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // The time leads, because a schedule is read by time first and
                // by drug name second.
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: actioned
                        ? Colors.white
                        : OnboardingColors.teal.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.scheduledTime,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: OnboardingColors.teal,
                        ),
                      ),
                      Text(
                        _partOfDay,
                        style: const TextStyle(
                          fontSize: 11,
                          color: OnboardingColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicationName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (item.dosage.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.dosage,
                          style: const TextStyle(
                            color: OnboardingColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actioned)
                  const Icon(Icons.check_circle,
                      color: OnboardingColors.teal, size: 26),
              ],
            ),
            if (!actioned) ...[
              const SizedBox(height: 12),
              // Labelled, full-width targets rather than two bare icons.
              // These write a medical record, and a mis-tap here says someone
              // took a dose they skipped.
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => onLog(DoseLogStatus.taken),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('กินแล้ว'),
                      style: FilledButton.styleFrom(
                        backgroundColor: OnboardingColors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onLog(DoseLogStatus.skipped),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OnboardingColors.textMuted,
                        side: const BorderSide(color: OnboardingColors.border),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ข้าม'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
