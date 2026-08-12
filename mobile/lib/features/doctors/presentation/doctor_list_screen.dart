import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../data/doctor_repository.dart';
import '../domain/entities/doctor.dart';
import 'doctor_detail_screen.dart';
import '../../../shared/theme/app_palette.dart';

/// The directory as a patient sees it: browse and message only. Adding or
/// editing a listing is an admin action — a patient publishing a doctor is how
/// unverified advice would reach other patients.
class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({
    super.key,
    required this.repository,
    required this.chatRepository,
    this.patientId,
  });

  final DoctorRepository repository;
  final ChatRepository chatRepository;
  final String? patientId;

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  late Future<List<Doctor>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = widget.repository.fetchAll();
  }

  Future<void> _openDoctor(Doctor doctor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorDetailScreen(
          doctor: doctor,
          chatRepository: widget.chatRepository,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.tint,
      appBar: AppBar(title: const Text('ปรึกษาแพทย์')),
      body: FutureBuilder<List<Doctor>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('โหลดข้อมูลแพทย์ไม่สำเร็จ'));
          }
          final doctors = snapshot.data ?? const <Doctor>[];
          if (doctors.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'ยังไม่มีแพทย์ในระบบ\nผู้ดูแลระบบจะเป็นผู้เพิ่มรายชื่อแพทย์',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OnboardingColors.textMuted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            separatorBuilder: (_, __) => const Divider(color: OnboardingColors.border),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              final photoUrl = doctor.photoUrl;
              return ListTile(
                onTap: () => _openDoctor(doctor),
                leading: CircleAvatar(
                  backgroundColor: OnboardingColors.teal,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.medical_services_outlined,
                          color: Colors.white, size: 20)
                      : null,
                ),
                title: Text(doctor.name),
                subtitle: Text(doctor.specialty),
                trailing: const Icon(Icons.chat_bubble_outline, size: 20),
              );
            },
          );
        },
      ),
    );
  }
}
