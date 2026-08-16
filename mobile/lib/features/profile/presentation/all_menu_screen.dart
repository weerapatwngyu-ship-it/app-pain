import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/data/caseload_repository.dart';
import '../../admin/presentation/admin_doctors_screen.dart';
import '../../admin/presentation/caseload_screen.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/conversation_list_screen.dart';
import '../../doctors/presentation/doctor_list_screen.dart';
import '../../health_topics/data/health_question_repository.dart';
import '../../health_topics/presentation/health_topics_screen.dart';
import '../../health_topics/presentation/my_questions_screen.dart';
import '../../peer_chat/data/peer_chat_repository.dart';
import '../../peer_chat/presentation/peer_chat_screen.dart';
import '../../pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../../pharmacy_finder/presentation/pharmacy_finder_screen.dart';
import '../../symptom_tracking/data/symptom_repository_impl.dart';
import '../../symptom_tracking/presentation/symptom_category_logs_screen.dart';
import '../data/patient_profile_repository.dart';
import 'personal_info_detail_screen.dart';
import 'settings_screen.dart';
import '../../../core/i18n/app_locale.dart';

/// Grid menu of every real feature in the app, grouped like the reference
/// design's "เมนูทั้งหมด" — every tile here opens a screen that actually
/// exists and does something (no NHSO/insurance/shopping items, since
/// MediGo doesn't have those).
class AllMenuScreen extends StatelessWidget {
  const AllMenuScreen({
    super.key,
    required this.user,
    required this.patientId,
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
    required this.onLogout,
  });

  final AppUser user;
  final String patientId;
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
  final VoidCallback onLogout;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('ออกจากระบบ', 'Sign out')),
        content: Text(t('ต้องการออกจากระบบใช่ไหม?', 'Sign out of your account?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('ออกจากระบบ', 'Sign out')),
          ),
        ],
      ),
    );
    if (confirmed == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(t('เมนูทั้งหมด', 'All menu'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel(t('ฟีเจอร์', 'Features')),
          _MenuGrid(tiles: [
            _MenuItem(
              icon: Icons.event_note_outlined,
              label: t('บันทึกอาการทั้งหมด', 'All symptom entries'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SymptomCategoryLogsScreen(
                    patientId: patientId,
                    repository: symptomRepository,
                    category: null,
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.medical_services_outlined,
              label: t('ปรึกษาแพทย์', 'Talk to a doctor'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorListScreen(
                    repository: doctorRepository,
                    chatRepository: chatRepository,
                    patientId: patientId,
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.local_pharmacy_outlined,
              label: t('ร้านยาใกล้ฉัน', 'Pharmacies near me'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PharmacyFinderScreen(repository: pharmacyFinderRepository),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.local_hospital_outlined,
              label: t('คลินิกออนไลน์', 'Online clinic'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HealthTopicsScreen(
                    patientId: patientId,
                    questionRepository: healthQuestionRepository,
                    doctorRepository: doctorRepository,
                    chatRepository: chatRepository,
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.chat_bubble_outline,
              label: t('ข้อความของฉัน', 'My messages'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConversationListScreen(
                    repository: chatRepository,
                    ownerId: patientId,
                    isDoctorView: false,
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.notifications_none,
              label: t('การแจ้งเตือนจากระบบ', 'System alerts'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlertsScreen(alertsRepository: alertsRepository),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.groups_outlined,
              label: t('คุยกับผู้ป่วยด้วยกัน', 'Talk to other patients'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PeerChatScreen(
                    patientId: patientId,
                    repository: peerChatRepository,
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.forum_outlined,
              label: t('คำถามของฉัน', 'My questions'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MyQuestionsScreen(
                    patientId: patientId,
                    repository: healthQuestionRepository,
                  ),
                ),
              ),
            ),
          ]),
          if (user.role == UserRole.admin) ...[
            const SizedBox(height: 24),
            _SectionLabel(t('ผู้ดูแลระบบ', 'Administration')),
            _MenuGrid(tiles: [
              _MenuItem(
                icon: Icons.verified_user_outlined,
                label: t('จัดการบัญชีแพทย์', 'Manage doctor accounts'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminDoctorsScreen(repository: adminRepository),
                  ),
                ),
              ),
              _MenuItem(
                icon: Icons.people_outline,
                label: t('ผู้ป่วยทั้งหมด', 'All patients'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaseloadScreen(repository: caseloadRepository),
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 24),
          _SectionLabel(t('บัญชีของฉัน', 'My account')),
          _MenuGrid(tiles: [
            _MenuItem(
              icon: Icons.person_outline,
              label: t('ข้อมูลส่วนตัว', 'Personal details'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PersonalInfoDetailScreen(
                    user: user,
                    authRepository: authRepository,
                    repository: patientProfileRepository,
                    onUserUpdated: onUserUpdated,
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: t('ตั้งค่า', 'Settings'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.logout,
              label: t('ออกจากระบบ', 'Sign out'),
              onTap: () => _confirmLogout(context),
            ),
          ]),
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.tiles});

  final List<_MenuItem> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: tiles.map((tile) => _MenuTile(item: tile)).toList(),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6F4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: OnboardingColors.teal),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
