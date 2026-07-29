import 'package:flutter/material.dart';

import '../features/alerts/presentation/screens/alerts_screen.dart';
import '../features/dashboard/presentation/screens/caregiver_dashboard_screen.dart';
import '../features/medication/presentation/screens/today_schedule_screen.dart';
import '../features/symptom_tracking/presentation/screens/log_symptom_screen.dart';

/// Bottom-nav shell so every feature screen is reachable from one
/// place. Stands in for real deep-linked navigation (push-triggered
/// alert screen, etc.) until the backend that would drive that exists.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.patientId});

  final String patientId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScheduleScreen(patientId: widget.patientId),
      LogSymptomScreen(patientId: widget.patientId),
      const AlertsScreen(),
      CaregiverDashboardScreen(patientId: widget.patientId),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'ตารางยา',
          ),
          NavigationDestination(
            icon: Icon(Icons.sick_outlined),
            selectedIcon: Icon(Icons.sick),
            label: 'บันทึกอาการ',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'แจ้งเตือน',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'ภาพรวม',
          ),
        ],
      ),
    );
  }
}
