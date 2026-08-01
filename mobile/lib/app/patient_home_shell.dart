import 'package:flutter/material.dart';

import '../features/alerts/data/alerts_repository.dart';
import '../features/alerts/presentation/alerts_screen.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/onboarding_theme.dart';
import '../features/medication/data/medication_repository_impl.dart';
import '../features/medication/domain/usecases/log_dose_usecase.dart';
import '../features/medication/presentation/today_schedule_screen.dart';
import '../features/pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../features/pharmacy_finder/presentation/pharmacy_finder_screen.dart';
import '../features/profile/data/patient_profile_repository.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/symptom_tracking/data/symptom_repository_impl.dart';
import '../features/symptom_tracking/domain/usecases/record_symptom_usecase.dart';
import '../features/symptom_tracking/presentation/symptom_log_screen.dart';

/// Bottom-nav shell for a logged-in patient — หน้าหลัก (today's dose
/// schedule) / กิจกรรม (symptom log) / แจ้งเตือน (alerts) / โปรไฟล์, plus a
/// center-docked FAB for ร้านขายยาใกล้ฉัน (nearby pharmacy finder).
class PatientHomeShell extends StatefulWidget {
  const PatientHomeShell({
    super.key,
    required this.user,
    required this.patientId,
    required this.medicationRepository,
    required this.symptomRepository,
    required this.alertsRepository,
    required this.patientProfileRepository,
    required this.pharmacyFinderRepository,
    required this.onLogout,
  });

  final AppUser user;
  final String patientId;
  final MedicationRepositoryImpl medicationRepository;
  final SymptomRepositoryImpl symptomRepository;
  final AlertsRepository alertsRepository;
  final PatientProfileRepository patientProfileRepository;
  final PharmacyFinderRepository pharmacyFinderRepository;
  final VoidCallback onLogout;

  @override
  State<PatientHomeShell> createState() => _PatientHomeShellState();
}

class _PatientHomeShellState extends State<PatientHomeShell> {
  int _index = 0;

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
        patientId: widget.patientId,
        medicationRepository: widget.medicationRepository,
        logDoseUseCase: LogDoseUseCase(widget.medicationRepository),
      ),
      SymptomLogScreen(
        patientId: widget.patientId,
        recordSymptomUseCase: RecordSymptomUseCase(widget.symptomRepository),
      ),
      AlertsScreen(alertsRepository: widget.alertsRepository),
      ProfileScreen(
        user: widget.user,
        onLogout: widget.onLogout,
        patientProfileRepository: widget.patientProfileRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: OnboardingColors.teal,
        tooltip: 'ร้านขายยาใกล้ฉัน',
        onPressed: _openPharmacyFinder,
        child: const Icon(Icons.local_pharmacy_outlined, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'หน้าหลัก',
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _NavItem(
              icon: Icons.event_note_outlined,
              label: 'กิจกรรม',
              selected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
            const SizedBox(width: 48), // space for the notched FAB
            _NavItem(
              icon: Icons.mail_outline,
              label: 'แจ้งเตือน',
              selected: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'โปรไฟล์',
              selected: _index == 3,
              onTap: () => setState(() => _index = 3),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
