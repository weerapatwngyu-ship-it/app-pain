import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_database.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/admin/presentation/admin_screen.dart';
import '../features/alerts/data/alerts_repository.dart';
import '../features/alerts/presentation/alerts_screen.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/phone_entry_screen.dart';
import '../features/medication/data/medication_repository_impl.dart';
import '../features/medication/domain/usecases/log_dose_usecase.dart';
import '../features/medication/presentation/today_schedule_screen.dart';
import '../features/symptom_tracking/data/symptom_repository_impl.dart';
import '../features/symptom_tracking/domain/usecases/record_symptom_usecase.dart';
import '../features/symptom_tracking/presentation/symptom_log_screen.dart';
import '../shared/theme/app_theme.dart';

class MedTrackApp extends StatefulWidget {
  const MedTrackApp({super.key, required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  State<MedTrackApp> createState() => _MedTrackAppState();
}

class _MedTrackAppState extends State<MedTrackApp> {
  late final ApiClient _apiClient = ApiClient(baseUrl: widget.apiBaseUrl);
  late final AuthRepositoryImpl _authRepository = AuthRepositoryImpl(_apiClient);
  late final MedicationRepositoryImpl _medicationRepository =
      MedicationRepositoryImpl(_apiClient, LocalDatabase.instance);
  late final SymptomRepositoryImpl _symptomRepository = SymptomRepositoryImpl(_apiClient);
  late final AlertsRepository _alertsRepository = AlertsRepository(_apiClient);
  late final AdminRepository _adminRepository = AdminRepository(_apiClient);

  AppUser? _currentUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTrack',
      theme: AppTheme.light(),
      home: _currentUser != null ? _buildHome(_currentUser!) : _buildLogin(),
    );
  }

  Widget _buildLogin() {
    return PhoneEntryScreen(
      authRepository: _authRepository,
      onAuthenticated: (user) => setState(() => _currentUser = user),
    );
  }

  void _logout() {
    _apiClient.setAccessToken(null);
    setState(() => _currentUser = null);
  }

  Widget _buildHome(AppUser user) {
    if (user.role == UserRole.admin) {
      return AdminScreen(adminRepository: _adminRepository, onLogout: _logout);
    }

    // Phase 1 MVP is otherwise patient-only (see docs/architecture.md
    // §11) — a caregiver/provider account has no owned patient profile
    // yet, so there's nothing meaningful to show them here.
    if (user.patientId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MedTrack'),
          actions: [
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'ออกจากระบบ'),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'บัญชี "${user.role.name}" ยังไม่รองรับในเวอร์ชันนี้ — Phase 1 รองรับเฉพาะบัญชีผู้ป่วย',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final patientId = user.patientId!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MedTrack'),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'ออกจากระบบ',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.medication_outlined), text: 'ยาวันนี้'),
              Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'บันทึกอาการ'),
              Tab(icon: Icon(Icons.notifications_outlined), text: 'แจ้งเตือน'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TodayScheduleScreen(
              patientId: patientId,
              medicationRepository: _medicationRepository,
              logDoseUseCase: LogDoseUseCase(_medicationRepository),
            ),
            SymptomLogScreen(
              patientId: patientId,
              recordSymptomUseCase: RecordSymptomUseCase(_symptomRepository),
            ),
            AlertsScreen(alertsRepository: _alertsRepository),
          ],
        ),
      ),
    );
  }
}
