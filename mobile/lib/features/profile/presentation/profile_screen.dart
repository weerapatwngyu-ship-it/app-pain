import 'package:flutter/material.dart';

import '../../../shared/widgets/avatar_picker.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/data/caseload_repository.dart';
import '../../chat/data/chat_repository.dart';
import '../../health_topics/data/health_question_repository.dart';
import '../../peer_chat/data/peer_chat_repository.dart';
import '../../pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../../symptom_tracking/data/symptom_repository_impl.dart';
import '../data/patient_profile_repository.dart';
import 'all_menu_screen.dart';
import 'personal_info_detail_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.patientId,
    required this.onLogout,
    required this.authRepository,
    required this.patientProfileRepository,
    required this.symptomRepository,
    required this.doctorRepository,
    required this.pharmacyFinderRepository,
    required this.healthQuestionRepository,
    required this.chatRepository,
    required this.alertsRepository,
    required this.peerChatRepository,
    required this.adminRepository,
    required this.caseloadRepository,
    required this.onUserUpdated,
  });

  final AppUser user;
  final String patientId;
  final VoidCallback onLogout;
  final AuthRepository authRepository;
  final PatientProfileRepository patientProfileRepository;
  final SymptomRepositoryImpl symptomRepository;
  final DoctorRepository doctorRepository;
  final PharmacyFinderRepository pharmacyFinderRepository;
  final HealthQuestionRepository healthQuestionRepository;
  final ChatRepository chatRepository;
  final AlertsRepository alertsRepository;
  final PeerChatRepository peerChatRepository;
  final AdminRepository adminRepository;
  final CaseloadRepository caseloadRepository;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  AppUser get user => widget.user;

  /// Short, human-friendly stand-in for a "member code" — derived from the
  /// account's real id (not fabricated), since the backend doesn't hand out
  /// a separate short code today.
  String get _userCode => user.id.replaceAll('-', '').substring(0, 6).toUpperCase();

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์นี้อยู่ระหว่างการพัฒนา')),
    );
  }

  Future<void> _changeAvatar() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                UserAvatar(
                  name: user.name,
                  avatarUrl: user.avatarUrl,
                  radius: 28,
                  onTap: _changeAvatar,
                  loading: _uploadingAvatar,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'รหัสผู้ใช้งาน: $_userCode',
                        style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                OnboardingIconButton(
                  icon: Icons.grid_view_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllMenuScreen(
                        user: user,
                        patientId: widget.patientId,
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
                        onLogout: widget.onLogout,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OnboardingIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OnboardingPrimaryButton(
              label: '+  เพิ่มสิทธิพิเศษ/กรมธรรม์',
              onPressed: () => _comingSoon(context),
            ),
            const SizedBox(height: 24),
            _SectionLabel('บัญชีผู้ใช้'),
            _MenuTile(
              icon: Icons.person_outline,
              label: 'แก้ไขข้อมูลส่วนตัว',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PersonalInfoDetailScreen(
                    user: user,
                    authRepository: widget.authRepository,
                    repository: widget.patientProfileRepository,
                    onUserUpdated: widget.onUserUpdated,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel('อื่นๆ'),
            _MenuTile(
              icon: Icons.logout,
              label: 'ออกจากระบบ',
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: OnboardingColors.textMuted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            Icon(icon, color: OnboardingColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
