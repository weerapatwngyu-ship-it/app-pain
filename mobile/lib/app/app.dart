import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_database.dart';
import '../features/alerts/data/alerts_repository.dart';
import '../features/alerts/presentation/alerts_screen.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/presentation/login_screen.dart';
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

  bool _loggedIn = false;
  // Placeholder until the auth session carries a real linked patient id.
  static const _demoPatientId = 'demo-patient';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTrack',
      theme: AppTheme.light(),
      home: _loggedIn ? _buildHome() : _buildLogin(),
    );
  }

  Widget _buildLogin() {
    return LoginScreen(
      authRepository: _authRepository,
      onLoggedIn: () => setState(() => _loggedIn = true),
    );
  }

  void _logout() {
    _apiClient.setAccessToken(null);
    setState(() => _loggedIn = false);
  }

  Widget _buildHome() {
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
              patientId: _demoPatientId,
              medicationRepository: _medicationRepository,
              logDoseUseCase: LogDoseUseCase(_medicationRepository),
            ),
            SymptomLogScreen(
              patientId: _demoPatientId,
              recordSymptomUseCase: RecordSymptomUseCase(_symptomRepository),
            ),
            AlertsScreen(alertsRepository: _alertsRepository),
          ],
        ),
      ),
    );
  }
}
