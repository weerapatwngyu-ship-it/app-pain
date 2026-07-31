import 'package:flutter/material.dart';

import '../features/alerts/data/alerts_repository.dart';
import '../features/alerts/presentation/alerts_screen.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/onboarding_theme.dart';
import '../features/medication/data/medication_repository_impl.dart';
import '../features/medication/domain/usecases/log_dose_usecase.dart';
import '../features/medication/presentation/today_schedule_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/symptom_tracking/data/symptom_repository_impl.dart';
import '../features/symptom_tracking/domain/usecases/record_symptom_usecase.dart';
import '../features/symptom_tracking/presentation/symptom_log_screen.dart';

/// Bottom-nav shell for a logged-in patient — หน้าหลัก (today's dose
/// schedule) / กิจกรรม (symptom log) / แจ้งเตือน (alerts) / โปรไฟล์.
class PatientHomeShell extends StatefulWidget {
  const PatientHomeShell({
    super.key,
    required this.user,
    required this.patientId,
    required this.medicationRepository,
    required this.symptomRepository,
    required this.alertsRepository,
    required this.onLogout,
  });

  final AppUser user;
  final String patientId;
  final MedicationRepositoryImpl medicationRepository;
  final SymptomRepositoryImpl symptomRepository;
  final AlertsRepository alertsRepository;
  final VoidCallback onLogout;

  @override
  State<PatientHomeShell> createState() => _PatientHomeShellState();
}

class _PatientHomeShellState extends State<PatientHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TodayScheduleScreen(
        patientId: widget.patientId,
        medicationRepository: widget.medicationRepository,
        logDoseUseCase: LogDoseUseCase(widget.medicationRepository),
      ),
      SymptomLogScreen(
        patientId: widget.patientId,
        recordSymptomUseCase: RecordSymptomUseCase(widget.symptomRepository),
      ),
      AlertsScreen(alertsRepository: widget.alertsRepository),
      ProfileScreen(user: widget.user, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: OnboardingColors.teal,
        unselectedItemColor: OnboardingColors.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'หน้าหลัก'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_outlined), label: 'กิจกรรม'),
          BottomNavigationBarItem(icon: Icon(Icons.mail_outline), label: 'แจ้งเตือน'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}
