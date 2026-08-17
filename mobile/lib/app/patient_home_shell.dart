import 'package:flutter/material.dart';

import '../core/i18n/app_locale.dart';
import '../features/alerts/data/alerts_repository.dart';
import '../features/reminders/data/reminder_repository.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/onboarding_theme.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/admin/data/caseload_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/doctors/data/doctor_repository.dart';
import '../features/health_topics/data/health_question_repository.dart';
import '../features/medication/data/medication_list_repository.dart';
import '../features/medication/data/medication_repository_impl.dart';
import '../features/medication/domain/usecases/log_dose_usecase.dart';
import '../features/medication/presentation/today_schedule_screen.dart';
import '../features/peer_chat/data/peer_chat_repository.dart';
import '../features/pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../features/pharmacy_finder/presentation/pharmacy_finder_screen.dart';
import '../features/profile/data/patient_profile_repository.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/symptom_tracking/data/symptom_repository_impl.dart';
import '../features/symptom_tracking/domain/usecases/record_symptom_usecase.dart';
import '../features/symptom_tracking/presentation/symptom_log_screen.dart';

/// Bottom nav for a logged-in patient — หน้าหลัก (today's dose schedule) /
/// กิจกรรม (symptom log) / ร้านยา (nearby pharmacy finder, opens as its own
/// screen rather than a tab) / แจ้งเตือน (alerts) / โปรไฟล์.
class PatientHomeShell extends StatefulWidget {
  const PatientHomeShell({
    super.key,
    required this.user,
    required this.patientId,
    required this.medicationRepository,
    required this.medicationListRepository,
    required this.symptomRepository,
    required this.alertsRepository,
    required this.patientProfileRepository,
    required this.pharmacyFinderRepository,
    required this.authRepository,
    required this.doctorRepository,
    required this.healthQuestionRepository,
    required this.chatRepository,
    required this.peerChatRepository,
    required this.adminRepository,
    required this.caseloadRepository,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final AppUser user;
  final String patientId;
  final MedicationRepositoryImpl medicationRepository;
  final MedicationListRepository medicationListRepository;
  final SymptomRepositoryImpl symptomRepository;
  final AlertsRepository alertsRepository;
  final PatientProfileRepository patientProfileRepository;
  final PharmacyFinderRepository pharmacyFinderRepository;
  final AuthRepository authRepository;
  final DoctorRepository doctorRepository;
  final HealthQuestionRepository healthQuestionRepository;
  final ChatRepository chatRepository;
  final PeerChatRepository peerChatRepository;
  final AdminRepository adminRepository;
  final CaseloadRepository caseloadRepository;

  final VoidCallback onLogout;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<PatientHomeShell> createState() => _PatientHomeShellState();
}

class _PatientHomeShellState extends State<PatientHomeShell> {
  int _index = 0;

  /// Local-only, so it is built here rather than threaded down from app.dart
  /// like the Supabase-backed repositories.
  final ReminderRepository _reminderRepository = ReminderRepository();

  /// Bumped whenever the home tab is re-selected. The tabs live in an
  /// IndexedStack and keep their state, so a doctor added from the admin
  /// screen would otherwise not appear until the app restarted.
  int _homeRefreshToken = 0;

  void _openPharmacyFinder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PharmacyFinderScreen(repository: widget.pharmacyFinderRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TodayScheduleScreen(
        refreshToken: _homeRefreshToken,
        user: widget.user,
        patientId: widget.patientId,
        medicationRepository: widget.medicationRepository,
        medicationListRepository: widget.medicationListRepository,
        patientProfileRepository: widget.patientProfileRepository,
        logDoseUseCase: LogDoseUseCase(widget.medicationRepository),
        symptomRepository: widget.symptomRepository,
        authRepository: widget.authRepository,
        doctorRepository: widget.doctorRepository,
        healthQuestionRepository: widget.healthQuestionRepository,
        chatRepository: widget.chatRepository,
        peerChatRepository: widget.peerChatRepository,
        reminderRepository: _reminderRepository,
        onOpenReminders: () => setState(() => _index = 2),
        onUserUpdated: widget.onUserUpdated,
      ),
      SymptomLogScreen(
        patientId: widget.patientId,
        recordSymptomUseCase: RecordSymptomUseCase(widget.symptomRepository),
        repository: widget.symptomRepository,
      ),
      RemindersScreen(
        repository: _reminderRepository,
        medicationRepository: widget.medicationRepository,
        patientId: widget.patientId,
      ),
      ProfileScreen(
        user: widget.user,
        patientId: widget.patientId,
        onLogout: widget.onLogout,
        authRepository: widget.authRepository,
        patientProfileRepository: widget.patientProfileRepository,
        symptomRepository: widget.symptomRepository,
        doctorRepository: widget.doctorRepository,
        pharmacyFinderRepository: widget.pharmacyFinderRepository,
        healthQuestionRepository: widget.healthQuestionRepository,
        chatRepository: widget.chatRepository,
        alertsRepository: widget.alertsRepository,
        peerChatRepository: widget.peerChatRepository,
        adminRepository: widget.adminRepository,
        caseloadRepository: widget.caseloadRepository,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: OnboardingColors.border)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: t('หน้าหลัก', 'Home'),
                selected: _index == 0,
                onTap: () => setState(() {
                  // Every tap on home re-reads the doctor row — including
                  // arriving from the profile tab, which is where an admin
                  // adds a doctor. Without this the listing would not appear
                  // until the app restarted.
                  _homeRefreshToken++;
                  _index = 0;
                }),
              ),
              _NavItem(
                icon: Icons.event_note_outlined,
                label: t('กิจกรรม', 'Activity'),
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
              _NavItem(
                icon: Icons.local_pharmacy_outlined,
                label: t('ร้านยา', 'Pharmacy'),
                selected: false,
                onTap: _openPharmacyFinder,
              ),
              _NavItem(
                icon: Icons.alarm,
                label: t('เตือนกินยา', 'Reminders'),
                selected: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: t('โปรไฟล์', 'Profile'),
                selected: _index == 3,
                onTap: () => setState(() => _index = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? OnboardingColors.teal : OnboardingColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
