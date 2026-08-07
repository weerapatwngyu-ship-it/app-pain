import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_screen.dart';
import '../domain/entities/doctor.dart';

/// Read-only for patients: the directory is maintained by an admin, and the
/// only thing a patient does here is start (or continue) a chat.
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({
    super.key,
    required this.doctor,
    required this.chatRepository,
    this.patientId,
  });

  final Doctor doctor;
  final ChatRepository chatRepository;

  /// Null when the viewer has no patient record (staff browsing the
  /// directory) — messaging needs a patient side, so the button is hidden.
  final String? patientId;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  bool _opening = false;

  Future<void> _openChat() async {
    final patientId = widget.patientId;
    if (patientId == null) return;

    setState(() => _opening = true);
    try {
      final conversation = await widget.chatRepository.openConversation(
        patientId: patientId,
        doctorId: widget.doctor.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversation.id,
            title: widget.doctor.name,
            subtitle: widget.doctor.specialty,
            repository: widget.chatRepository,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดแชทไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final photoUrl = doctor.photoUrl;
    final canChat = widget.patientId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('โปรไฟล์แพทย์')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: OnboardingColors.teal,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.medical_services_outlined, color: Colors.white, size: 40)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            doctor.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            doctor.specialty,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OnboardingColors.teal,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('ข้อมูลเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(doctor.bio!, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 32),
          if (canChat)
            OnboardingPrimaryButton(
              label: 'ส่งข้อความหาแพทย์',
              loading: _opening,
              onPressed: _opening ? null : _openChat,
            )
          else
            const Text(
              'บัญชีนี้ไม่มีข้อมูลผู้ป่วย จึงยังส่งข้อความไม่ได้',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
            ),
          const SizedBox(height: 12),
          const Text(
            'ข้อความในแอปไม่ใช่ช่องทางฉุกเฉิน — หากมีอาการรุนแรง โทร 1669',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
          ),
        ],
      ),
    );
  }
}
