import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/user_avatar.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../health_topics/data/health_question_repository.dart';
import '../../health_topics/presentation/health_topics_screen.dart';
import '../../health_topics/presentation/question_queue_screen.dart';
import '../../pharmacy_finder/data/pharmacy_finder_repository.dart';
import '../../pharmacy_finder/presentation/pharmacy_finder_screen.dart';
import '../../profile/presentation/settings_screen.dart';
import '../domain/entities/doctor.dart';

/// The doctor's own account page.
///
/// Deliberately not a copy of the patient profile: a doctor has no medication
/// schedule, symptom log or health questions of their own here, so this shows
/// the listing patients actually see plus the few app features that make sense
/// without a patient record behind them.
class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({
    super.key,
    required this.user,
    required this.doctor,
    required this.pharmacyFinderRepository,
    required this.healthQuestionRepository,
    required this.doctorRepository,
    required this.chatRepository,
    required this.onLogout,
  });

  final AppUser user;
  final Doctor doctor;
  final PharmacyFinderRepository pharmacyFinderRepository;
  final HealthQuestionRepository healthQuestionRepository;
  final DoctorRepository doctorRepository;
  final ChatRepository chatRepository;
  final VoidCallback onLogout;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  /// The listing as it stands now, so a newly uploaded photo shows without
  /// waiting for the shell above to re-query.
  late Doctor _doctor = widget.doctor;
  bool _uploadingPhoto = false;

  AppUser get user => widget.user;
  Doctor get doctor => _doctor;

  /// A doctor's photo is the one on their listing, not their account avatar —
  /// that listing is what patients see, so it is the one worth changing.
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return;
      final updated = await widget.doctorRepository.uploadPhoto(
        _doctor.id,
        fileBytes: await picked.readAsBytes(),
        fileName: picked.name,
      );
      if (mounted) setState(() => _doctor = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            UserAvatar(
              name: doctor.name,
              avatarUrl: doctor.photoUrl,
              radius: 32,
              onTap: _changePhoto,
              loading: _uploadingPhoto,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialty,
                    style: const TextStyle(
                        fontSize: 13, color: OnboardingColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(
                        fontSize: 12, color: OnboardingColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (doctor.bio != null && doctor.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              doctor.bio!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'ข้อมูลนี้คือสิ่งที่ผู้ป่วยเห็นในหน้าแรก '
            'รูปแตะเพื่อเปลี่ยนได้เอง ส่วนชื่อและสาขาความเชี่ยวชาญ '
            'ต้องติดต่อผู้ดูแลระบบ',
            style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
          ),
        ),
        const Divider(height: 32),
        _MenuTile(
          icon: Icons.forum_outlined,
          label: 'คำถามจากผู้ป่วย',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuestionQueueScreen(repository: widget.healthQuestionRepository),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.local_hospital_outlined,
          label: 'คลินิกออนไลน์',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              // No patientId: a doctor browses the catalogue for reference and
              // has no questions of their own to ask, so the "ask" affordances
              // stay hidden.
              builder: (_) => HealthTopicsScreen(
                patientId: null,
                questionRepository: widget.healthQuestionRepository,
                doctorRepository: widget.doctorRepository,
                chatRepository: widget.chatRepository,
              ),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.local_pharmacy_outlined,
          label: 'ร้านยาและคลินิกใกล้ฉัน',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PharmacyFinderScreen(repository: widget.pharmacyFinderRepository),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.settings_outlined,
          label: 'ตั้งค่า',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        _MenuTile(
          icon: Icons.logout,
          label: 'ออกจากระบบ',
          onTap: () => _confirmLogout(context),
        ),
      ],
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: OnboardingColors.teal),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
