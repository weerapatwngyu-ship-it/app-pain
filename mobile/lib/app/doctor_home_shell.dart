import 'package:flutter/material.dart';

import '../features/auth/domain/entities/user.dart';
import '../features/auth/presentation/onboarding/onboarding_theme.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/conversation_list_screen.dart';
import '../features/doctors/domain/entities/doctor.dart';

/// What a signed-in doctor sees. Phase 1 gives them the one thing patients
/// can reach them through — the message threads — rather than a cut-down copy
/// of the patient app, which would show them medication and symptom screens
/// belonging to nobody.
class DoctorHomeShell extends StatelessWidget {
  const DoctorHomeShell({
    super.key,
    required this.user,
    required this.doctor,
    required this.chatRepository,
    required this.onLogout,
  });

  final AppUser user;
  final Doctor doctor;
  final ChatRepository chatRepository;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doctor.name, style: const TextStyle(fontSize: 17)),
            Text(
              doctor.specialty,
              style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: ConversationListScreen(
        repository: chatRepository,
        ownerId: doctor.id,
        isDoctorView: true,
        showBackButton: false,
      ),
    );
  }
}

/// Shown to an account whose role says provider but which has no listing yet.
/// Without a `doctors` row there is nothing for patients to message, so this
/// says so plainly instead of presenting an empty inbox that will never fill.
class DoctorPendingScreen extends StatelessWidget {
  const DoctorPendingScreen({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MedTrack'),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty, size: 56, color: OnboardingColors.teal),
              const SizedBox(height: 20),
              const Text(
                'บัญชีนี้ยังไม่ได้รับการอนุมัติ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'บัญชี ${user.email} ถูกตั้งเป็นบุคลากรทางการแพทย์แล้ว '
                'แต่ผู้ดูแลระบบยังไม่ได้สร้างโปรไฟล์แพทย์ให้ '
                'ผู้ป่วยจึงยังไม่เห็นและส่งข้อความหาไม่ได้',
                textAlign: TextAlign.center,
                style: const TextStyle(color: OnboardingColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
