import 'package:flutter/material.dart';

import '../core/i18n/app_locale.dart';
import '../shared/widgets/unread_dot.dart';

import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/onboarding_theme.dart';
import '../features/admin/data/caseload_repository.dart';
import '../features/admin/presentation/caseload_screen.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/conversation_list_screen.dart';
import '../features/doctors/data/doctor_repository.dart';
import '../features/doctors/domain/entities/doctor.dart';
import '../features/health_topics/data/health_question_repository.dart';
import '../features/doctors/presentation/doctor_profile_screen.dart';
import '../features/pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../features/medication/data/medication_list_repository.dart';

/// What a signed-in doctor sees: the threads patients opened with them, and
/// the full caseload. Not a cut-down copy of the patient app — a doctor has no
/// medication schedule or symptom log of their own to show.
class DoctorHomeShell extends StatefulWidget {
  const DoctorHomeShell({
    super.key,
    required this.user,
    required this.doctor,
    required this.chatRepository,
    required this.caseloadRepository,
    required this.medicationListRepository,
    required this.pharmacyFinderRepository,
    required this.healthQuestionRepository,
    required this.doctorRepository,
    required this.onLogout,
  });

  final AppUser user;
  final Doctor doctor;
  final ChatRepository chatRepository;
  final CaseloadRepository caseloadRepository;

  /// Used for prescribing from a patient's record.
  final MedicationListRepository medicationListRepository;
  final PharmacyFinderRepository pharmacyFinderRepository;
  final HealthQuestionRepository healthQuestionRepository;
  final DoctorRepository doctorRepository;
  final VoidCallback onLogout;

  @override
  State<DoctorHomeShell> createState() => _DoctorHomeShellState();
}

class _DoctorHomeShellState extends State<DoctorHomeShell> {
  int _index = 0;

  /// Patients waiting on a reply. Read on arrival and again whenever the
  /// doctor leaves the inbox, which is when it can have changed.
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final count =
          await widget.chatRepository.unreadForDoctor(widget.doctor.id);
      if (!mounted || count == _unread) return;
      setState(() => _unread = count);
    } catch (error) {
      // A badge that cannot be counted is not worth an error on screen.
      debugPrint('unreadForDoctor failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final tabs = [
      ConversationListScreen(
        repository: widget.chatRepository,
        ownerId: doctor.id,
        isDoctorView: true,
        showBackButton: false,
        onThreadsRead: _loadUnread,
      ),
      CaseloadScreen(
        repository: widget.caseloadRepository,
        chatRepository: widget.chatRepository,
        doctorId: doctor.id,
        medicationRepository: widget.medicationListRepository,
      ),
      DoctorProfileScreen(
        user: widget.user,
        doctor: doctor,
        pharmacyFinderRepository: widget.pharmacyFinderRepository,
        healthQuestionRepository: widget.healthQuestionRepository,
        doctorRepository: widget.doctorRepository,
        chatRepository: widget.chatRepository,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doctor.name, style: const TextStyle(fontSize: 17)),
            Text(
              doctor.specialty,
              style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: t('ออกจากระบบ', 'Sign out'),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Leaving the inbox is the moment its count can have gone down.
          if (i != 0) _loadUnread();
        },
        destinations: [
          NavigationDestination(
            icon: UnreadBadge(
              show: _unread > 0,
              borderColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: t('ข้อความ', 'Messages'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: t('ผู้ป่วย', 'Patients'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t('โปรไฟล์', 'Profile'),
          ),
        ],
      ),
    );
  }
}

/// Shown to an account whose role says provider but which has no listing yet.
/// Without a `doctors` row there is nothing for patients to message, so this
/// says so plainly instead of presenting an empty inbox that will never fill.
class DoctorPendingScreen extends StatelessWidget {
  const DoctorPendingScreen({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MediGo'),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: t('ออกจากระบบ', 'Sign out'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty, size: 56, color: OnboardingColors.teal),
              const SizedBox(height: 20),
              const Text(
                'บัญชีนี้ยังไม่ได้รับการอนุมัติ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'บัญชี ${user.email} ถูกตั้งเป็นบุคลากรทางการแพทย์แล้ว '
                'แต่ผู้ดูแลระบบยังไม่ได้สร้างโปรไฟล์แพทย์ให้ '
                'ผู้ป่วยจึงยังไม่เห็นและส่งข้อความหาไม่ได้',
                textAlign: TextAlign.center,
                style: const TextStyle(color: OnboardingColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
