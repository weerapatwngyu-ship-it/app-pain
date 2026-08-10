import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/storage/local_database.dart';
import '../features/alerts/data/alerts_repository.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/admin/data/caseload_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/doctors/data/doctor_repository.dart';
import '../features/doctors/domain/entities/doctor.dart';
import '../features/health_topics/data/health_question_repository.dart';
import '../features/medication/data/medication_repository_impl.dart';
import '../features/peer_chat/data/peer_chat_repository.dart';
import '../features/pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../features/profile/data/patient_profile_repository.dart';
import '../features/symptom_tracking/data/symptom_repository_impl.dart';
import '../shared/theme/app_theme.dart';
import 'doctor_home_shell.dart';
import 'patient_home_shell.dart';

class MedTrackApp extends StatefulWidget {
  const MedTrackApp({super.key, this.googleWebClientId});

  /// Null when GOOGLE_WEB_CLIENT_ID wasn't passed at build time — the sign-in
  /// screen hides the Google button rather than offering a flow that would
  /// only fail.
  final String? googleWebClientId;

  @override
  State<MedTrackApp> createState() => _MedTrackAppState();
}

class _MedTrackAppState extends State<MedTrackApp> {
  final AuthRepositoryImpl _authRepository = AuthRepositoryImpl();
  final MedicationRepositoryImpl _medicationRepository =
      MedicationRepositoryImpl(LocalDatabase.instance);
  final SymptomRepositoryImpl _symptomRepository = SymptomRepositoryImpl();
  final AlertsRepository _alertsRepository = AlertsRepository();
  final PatientProfileRepository _patientProfileRepository = PatientProfileRepository();
  final PharmacyFinderRepository _pharmacyFinderRepository = PharmacyFinderRepository();
  final DoctorRepository _doctorRepository = DoctorRepository();
  final HealthQuestionRepository _healthQuestionRepository = HealthQuestionRepository();
  final ChatRepository _chatRepository = ChatRepository();
  final PeerChatRepository _peerChatRepository = PeerChatRepository();
  final AdminRepository _adminRepository = AdminRepository();
  final CaseloadRepository _caseloadRepository = CaseloadRepository();

  /// Cached so rebuilding the shell doesn't re-query the listing each frame;
  /// cleared whenever the session changes.
  Future<Doctor?>? _doctorListingFuture;

  StreamSubscription<AuthState>? _authSubscription;

  AppUser? _currentUser;
  bool _resolvingUser = true;
  bool _sessionExpiredNotice = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();

    // Supabase restores any saved session before emitting, and emits again
    // once signInWithIdToken (email/password or Google) resolves — so one
    // listener covers both cold start and completing a sign-in.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      _applySession(state.session);
    });
    _applySession(Supabase.instance.client.auth.currentSession);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Mirrors the Supabase session onto the API client, then loads the
  /// app-side profile that carries role and patientId.
  Future<void> _applySession(Session? session) async {
    _doctorListingFuture = null;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _resolvingUser = false;
      });
      return;
    }

    if (mounted) setState(() => _resolvingUser = true);
    try {
      final user = await _authRepository.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _profileError = null;
        _sessionExpiredNotice = false;
        _resolvingUser = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = 'โหลดข้อมูลผู้ใช้ไม่สำเร็จ — ตรวจสอบว่าเซิร์ฟเวอร์ทำงานอยู่\n\n$e';
        _resolvingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTrack',
      theme: AppTheme.light(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_resolvingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profileError != null) return _buildProfileError();
    final user = _currentUser;
    if (user == null) {
      return SignInScreen(
        notice: _sessionExpiredNotice ? 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' : null,
        googleWebClientId: widget.googleWebClientId,
      );
    }
    return _buildSignedIn(user);
  }

  Widget _buildProfileError() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_profileError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _applySession(Supabase.instance.client.auth.currentSession),
                child: const Text('ลองอีกครั้ง'),
              ),
              TextButton(onPressed: _logout, child: const Text('ออกจากระบบ')),
            ],
          ),
        ),
      ),
    );
  }

  void _handleUserUpdated(AppUser user) => setState(() => _currentUser = user);

  void _logout() {
    unawaited(Supabase.instance.client.auth.signOut());
  }

  Widget _buildSignedIn(AppUser user) {
    // A doctor gets the inbox, not a patient app with nobody's medication in
    // it. The listing — not the role — is what decides: role says which shell
    // to try, but threads hang off the `doctors` row, so an approved-but-
    // unlisted account has nothing to show and is told why.
    if (user.role == UserRole.provider) {
      return FutureBuilder<Doctor?>(
        future: _doctorListingFuture ??= _doctorRepository.fetchForCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final doctor = snapshot.data;
          if (doctor == null) {
            return DoctorPendingScreen(user: user, onLogout: _logout);
          }
          return DoctorHomeShell(
            user: user,
            doctor: doctor,
            chatRepository: _chatRepository,
            caseloadRepository: _caseloadRepository,
            pharmacyFinderRepository: _pharmacyFinderRepository,
            onLogout: _logout,
          );
        },
      );
    }

    // Caregiver accounts have no owned patient record yet (Phase 2).
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
      healthQuestionRepository: _healthQuestionRepository,
      chatRepository: _chatRepository,
      peerChatRepository: _peerChatRepository,
      adminRepository: _adminRepository,
      caseloadRepository: _caseloadRepository,
      onLogout: _logout,
      onUserUpdated: _handleUserUpdated,
    );
  }
}
