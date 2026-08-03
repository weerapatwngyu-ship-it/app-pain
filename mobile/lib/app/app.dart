import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_database.dart';
import '../core/storage/session_storage.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/admin/presentation/admin_screen.dart';
import '../features/alerts/data/alerts_repository.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/phone_entry_screen.dart';
import '../features/doctors/data/doctor_repository.dart';
import '../features/medication/data/medication_repository_impl.dart';
import '../features/pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../features/profile/data/patient_profile_repository.dart';
import '../features/symptom_tracking/data/symptom_repository_impl.dart';
import '../shared/theme/app_theme.dart';
import 'patient_home_shell.dart';

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
  late final PatientProfileRepository _patientProfileRepository =
      PatientProfileRepository(_apiClient);
  late final PharmacyFinderRepository _pharmacyFinderRepository =
      PharmacyFinderRepository(_apiClient);
  late final DoctorRepository _doctorRepository = DoctorRepository(_apiClient);
  final SessionStorage _sessionStorage = SessionStorage();

  AppUser? _currentUser;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _sessionStorage.load();
    if (session != null) {
      _apiClient.setAccessToken(session.accessToken);
    }
    if (!mounted) return;
    setState(() {
      _currentUser = session?.user;
      _restoringSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTrack',
      theme: AppTheme.light(),
      home: _restoringSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_currentUser != null ? _buildHome(_currentUser!) : _buildLogin()),
    );
  }

  Widget _buildLogin() {
    return PhoneEntryScreen(
      authRepository: _authRepository,
      onAuthenticated: _handleAuthenticated,
    );
  }

  void _handleAuthenticated(AppUser user) {
    setState(() => _currentUser = user);
    final token = _apiClient.accessToken;
    if (token != null) {
      _sessionStorage.save(AuthSession(accessToken: token, user: user));
    }
  }

  void _logout() {
    _apiClient.setAccessToken(null);
    _sessionStorage.clear();
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

    return PatientHomeShell(
      user: user,
      patientId: user.patientId!,
      medicationRepository: _medicationRepository,
      symptomRepository: _symptomRepository,
      alertsRepository: _alertsRepository,
      patientProfileRepository: _patientProfileRepository,
      pharmacyFinderRepository: _pharmacyFinderRepository,
      authRepository: _authRepository,
      doctorRepository: _doctorRepository,
      mediaBaseUrl: _apiClient.originUrl,
      onLogout: _logout,
      onUserUpdated: _handleAuthenticated,
    );
  }
}
