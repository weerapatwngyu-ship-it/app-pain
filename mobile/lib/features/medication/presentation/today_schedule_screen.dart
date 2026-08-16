import 'package:flutter/material.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../shared/format/thai_date.dart';
import '../../../shared/widgets/auto_scroll_strip.dart';
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
import '../../reminders/data/reminder_repository.dart';
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
    required this.reminderRepository,
    required this.onOpenReminders,
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

  /// The phone's alarms. This screen owns keeping them in step with the
  /// doctor's schedule, because it is the one place that reads that schedule
  /// on every app open.
  final ReminderRepository reminderRepository;

  /// Switches to the เตือนกินยา tab. The alarms are generated from the
  /// schedule shown here, so the two screens are one feature and the list
  /// links straight through to them.
  final VoidCallback onOpenReminders;

  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  late Future<List<DoseScheduleItem>> _scheduleFuture;
  late Future<Map<String, int>> _categoryCountsFuture;
  late Future<List<Doctor>> _doctorsFuture;

  /// Doses already logged today, taken or skipped.
  ///
  /// Seeded from the database whenever the schedule loads. It used to hold
  /// only what had been ticked since the screen opened, so reopening the app
  /// showed the morning's doses untaken and invited a second one.
  final Set<String> _actionedScheduleIds = {};

  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = _loadSchedule();
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

  /// Today's doses, plus which of them are already logged.
  ///
  /// Also the point where the three halves of the reminder loop meet: the
  /// doctor's schedule becomes the phone's alarms, any dose answered from a
  /// notification while the app was closed becomes a dose log, and the result
  /// is what the list paints. Doing it here rather than at launch means it
  /// happens on every app open and on every pull to refresh, without a second
  /// place that has to remember to.
  ///
  /// The schedule is fetched together with what has been logged, so the list
  /// never paints a dose as outstanding for a frame before the log arrives and
  /// ticks it.
  Future<List<DoseScheduleItem>> _loadSchedule() async {
    final items =
        await widget.medicationRepository.todaySchedule(widget.patientId);

    // Doses confirmed from the notification itself. They were parked on the
    // platform side with the time they were actually answered, since there was
    // no app running to record them.
    //
    // Before the sync below, not after: a mark names a reminder, and the sync
    // deletes the reminders of any medication the doctor has since stopped —
    // which would throw away a dose the patient had already confirmed.
    try {
      for (final dose in await widget.reminderRepository.drainTakenDoses()) {
        await widget.logDoseUseCase(DoseLog(
          scheduleId: dose.scheduleId,
          scheduledAt: dose.at,
          actionedAt: dose.at,
          status: DoseLogStatus.taken,
        ));
      }
    } catch (error) {
      debugPrint('drainTakenDoses failed: $error');
    }

    // The times the doctor set become the alarms the phone rings. Failing here
    // must not cost the schedule on screen: an alarm that did not get set is a
    // missed reminder, but a blank screen is a patient who cannot see their
    // medication at all.
    try {
      await widget.reminderRepository.syncFromSchedule(items);
    } catch (error) {
      debugPrint('syncFromSchedule failed: $error');
    }

    // Anything still queued from an earlier offline write. Until this runs the
    // dose is recorded on the phone only, and the doctor cannot see it.
    try {
      await widget.medicationRepository.syncPending();
    } catch (error) {
      debugPrint('syncPending failed: $error');
    }

    try {
      final logged = await widget.medicationRepository
          .loggedToday(items.map((item) => item.scheduleId).toList());
      _actionedScheduleIds
        ..clear()
        ..addAll(logged);
    } catch (error) {
      // Showing the schedule matters more than showing it ticked; a failure
      // here means the day looks untaken, which the patient can correct, and
      // logging again is harmless.
      debugPrint('loggedToday failed: $error');
    }
    return items;
  }

  void _reloadSchedule() {
    setState(() {
      _scheduleFuture = _loadSchedule();
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
          doctorRepository: widget.doctorRepository,
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
      SnackBar(
          content: Text(t('บันทึกแล้ว: ${item.medicationName}',
              'Recorded: ${item.medicationName}'))),
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
    if (hour < 6) return t('สวัสดีตอนดึก', 'Good night');
    if (hour < 12) return t('สวัสดีตอนเช้า', 'Good morning');
    if (hour < 18) return t('สวัสดีตอนบ่าย', 'Good afternoon');
    return t('สวัสดีตอนเย็น', 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // top: false because the banner reaches under the status bar on purpose
      // and applies that inset itself; SafeArea would push it down and leave a
      // white strip above the colour.
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<DoseScheduleItem>>(
          future: _scheduleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(t('โหลดตารางยาไม่สำเร็จ',
                    'Could not load your doses')));
            }
            final items = snapshot.data ?? [];
            final doneCount = items
                .where((item) => _actionedScheduleIds.contains(item.scheduleId))
                .length;

            // The backend returns today's doses ordered by time, so the first
            // one still unlogged is the next one due.
            DoseScheduleItem? nextDose;
            for (final item in items) {
              if (!_actionedScheduleIds.contains(item.scheduleId)) {
                nextDose = item;
                break;
              }
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // Greeting and today's summary read as one coloured banner
                // rather than a white strip above a green card. It also gives
                // the status bar something to sit on, which was the point:
                // the top of the screen should look like a header.
                _HomeBanner(
                  greeting: _greeting,
                  name: widget.user.name,
                  avatarUrl: widget.user.avatarUrl,
                  uploadingAvatar: _uploadingAvatar,
                  onAvatarTap: _pickAndUploadAvatar,
                  total: items.length,
                  done: doneCount,
                  nextDose: nextDose,
                  onOpenList: _openMedicationList,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // With nothing scheduled the card above already says so and
                // offers the one thing to do about it, so the section is left
                // out entirely rather than repeating the message under an
                // empty heading.
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: t('ตารางยาวันนี้', "Today's doses"),
                    actionLabel: t('ยาของฉัน', 'My medication'),
                    actionIcon: Icons.medication_outlined,
                    onAction: _openMedicationList,
                  ),
                  const SizedBox(height: 10),
                  _ReminderNote(onTap: widget.onOpenReminders),
                  const SizedBox(height: 12),
                  ...items.map((item) => _DoseTile(
                        item: item,
                        actioned: _actionedScheduleIds.contains(item.scheduleId),
                        onLog: (status) => _logDose(item, status),
                      )),
                ],
                const SizedBox(height: 28),
                _SectionHeader(
                  title: t('ปรึกษาแพทย์', 'Talk to a doctor'),
                  actionLabel: t('ดูทั้งหมด', 'See all'),
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
                      return SizedBox(
                        height: 72,
                        child: Center(
                          child: Text(
                            t('ยังไม่มีแพทย์ในระบบ', 'No doctors listed yet'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: OnboardingColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    }
                    return AutoScrollStrip(
                      height: 148,
                      itemCount: doctors.length,
                      itemBuilder: (context, index) {
                        final doctor = doctors[index];
                        return _DoctorTile(
                          doctor: doctor,
                          onTap: () => _openDoctor(doctor),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: t('คลินิกออนไลน์', 'Online clinic'),
                  actionLabel: t('ดูทั้งหมด', 'See all'),
                  onAction: _openHealthTopics,
                ),
                const SizedBox(height: 10),
                // Drifts on its own: there are more topics than fit, and a row
                // that sits still gives no sign it continues past the edge.
                AutoScrollStrip(
                  height: 108,
                  itemCount: healthTopics.length,
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
                    return AutoScrollStrip(
                      height: 96,
                      itemCount: symptomCategories.length,
                      itemBuilder: (context, index) {
                        final category = symptomCategories[index];
                        return _CategoryTile(
                          category: category,
                          count: counts[category.key] ?? 0,
                          onTap: () => _openCategory(category.key),
                        );
                      },
                    );
                  },
                ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Today, as "วันอังคาร 12 ส.ค. 2568" — a screen headed "ยาวันนี้" should say
/// which day that is.
String _thaiToday() {
  final now = DateTime.now();
  if (LocaleController.instance.isEnglish) {
    return '${englishWeekdays[now.weekday - 1]} ${englishDate(now)}';
  }
  return 'วัน${thaiWeekdays[now.weekday - 1]} ${thaiDate(now)}';
}

/// The coloured top of the home screen: who is signed in, what day it is,
/// and how today's doses stand — one band rather than a white strip above a
/// green card.
///
/// Runs to the top of the display, behind the status bar, so the tinted area
/// reads as a header instead of stopping short in a line across the screen.
class _HomeBanner extends StatelessWidget {
  const _HomeBanner({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.uploadingAvatar,
    required this.onAvatarTap,
    required this.total,
    required this.done,
    required this.nextDose,
    required this.onOpenList,
  });

  final String greeting;
  final String name;
  final String? avatarUrl;
  final bool uploadingAvatar;
  final VoidCallback onAvatarTap;
  final int total;
  final int done;
  final DoseScheduleItem? nextDose;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OnboardingColors.teal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      // Only the top inset: the rounded bottom is the banner's own edge, not
      // a system boundary.
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _thaiToday(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Inside the banner the summary no longer needs its own colour, so
          // it becomes a translucent panel — one tinted region instead of two
          // greens stacked on each other.
          _TodaySummaryPanel(
            total: total,
            done: done,
            nextDose: nextDose,
            onOpenList: onOpenList,
          ),
        ],
      ),
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
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: OnboardingColors.teal,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.medical_services_outlined,
                      color: Colors.white, size: 22)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              doctor.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 1),
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
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5F3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(topic.icon, color: OnboardingColors.teal, size: 29),
            ),
            const SizedBox(height: 7),
            Text(
              topic.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w500),
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
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
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

/// The card at the top of the home screen.
///
/// Two genuinely different states rather than one layout with the numbers
/// swapped. With nothing scheduled, a progress bar shows progress through
/// nothing and the card repeated the same "none today" the section below
/// already said; that space now carries the one useful action instead. With
/// doses on it, the card answers the question actually being asked — how far
/// through today am I, and what is next.
/// Today's doses, as a panel inside the banner.
///
/// Sits on the banner's teal, so it carries a translucent white fill instead
/// of a colour of its own — two greens stacked read as a mistake.
class _TodaySummaryPanel extends StatelessWidget {
  const _TodaySummaryPanel({
    required this.total,
    required this.done,
    required this.nextDose,
    required this.onOpenList,
  });

  final int total;
  final int done;

  /// Earliest dose not yet logged. Null once everything is done.
  final DoseScheduleItem? nextDose;

  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: total == 0 ? _buildEmpty(context) : _buildProgress(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ยังไม่มียาที่ต้องกินวันนี้',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        // No "add" here any more: prescribing belongs to the doctor, and a
        // button the patient cannot complete would only lead somewhere empty.
        const Text(
          'เมื่อแพทย์สั่งยาให้ ยาจะขึ้นที่นี่พร้อมเวลาที่ต้องกิน '
          'และแอปจะเตือนตามเวลานั้นทุกวัน',
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpenList,
            icon: const Icon(Icons.medication_outlined, size: 20),
            label: const Text('ดูรายการยาของฉัน'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: OnboardingColors.teal,
              minimumSize: const Size.fromHeight(46),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    final allDone = done >= total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('ยาวันนี้', "Today's doses"),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    allDone
                        ? t('ครบแล้ววันนี้', 'All done for today')
                        : t('บันทึกแล้ว $done จาก $total',
                            '$done of $total recorded'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      strokeWidth: 5,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  if (allDone)
                    const Icon(Icons.check, color: Colors.white, size: 24)
                  else
                    Text(
                      '$done/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (nextDose != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('ถัดไป ${nextDose!.scheduledTime} · ${nextDose!.medicationName}',
                      'Next ${nextDose!.scheduledTime} · ${nextDose!.medicationName}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        InkWell(
          onTap: onOpenList,
          child: const Row(
            children: [
              Text('ดูยาทั้งหมดของฉัน',
                  style: TextStyle(color: Colors.white, fontSize: 13.5)),
              Icon(Icons.chevron_right, size: 18, color: Colors.white),
            ],
          ),
        ),
      ],
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

/// Says where these times came from and that the phone will ring for them.
///
/// Worth a line of its own: the patient never entered any of this, so without
/// being told, a schedule that appeared by itself looks like something they
/// still have to set an alarm for by hand — which is exactly the double work
/// the generated reminders exist to remove.
class _ReminderNote extends StatelessWidget {
  const _ReminderNote({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 18, color: OnboardingColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t(
                  'แพทย์ตั้งเวลาให้ แอปจะเตือนอัตโนมัติทุกวัน\n'
                      'กด "กินแล้ว" บนการแจ้งเตือนได้เลย ระบบบันทึกให้ทันที',
                  'Your doctor set these times; the app reminds you daily.\n'
                      'Press "Taken" on the notification and it is recorded.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: OnboardingColors.teal,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: OnboardingColors.teal),
          ],
        ),
      ),
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
    if (hour < 5) return t('กลางคืน', 'Night');
    if (hour < 11) return t('เช้า', 'Morning');
    if (hour < 15) return t('กลางวัน', 'Midday');
    if (hour < 19) return t('เย็น', 'Evening');
    return t('ก่อนนอน', 'Bedtime');
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
                      label: Text(t('กินแล้ว', 'Taken')),
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
                      child: Text(t('ข้าม', 'Skip')),
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
