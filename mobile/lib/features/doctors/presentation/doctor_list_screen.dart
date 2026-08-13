import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../data/doctor_repository.dart';
import '../domain/entities/doctor.dart';
import 'doctor_card.dart';
import 'doctor_detail_screen.dart';

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

  /// Consultation totals, filled in per doctor as they arrive.
  ///
  /// Fetched after the list rather than as part of it, so a slow count — or a
  /// failing one — delays a number on a card instead of the whole directory.
  final Map<String, int> _consultCounts = {};

  @override
  void initState() {
    super.initState();
    _doctorsFuture = widget.repository.fetchAll().then((doctors) {
      _loadCounts(doctors);
      return doctors;
    });
  }

  Future<void> _loadCounts(List<Doctor> doctors) async {
    for (final doctor in doctors) {
      try {
        final count = await widget.repository.consultCount(doctor.id);
        if (!mounted) return;
        setState(() => _consultCounts[doctor.id] = count);
      } catch (_) {
        // A missing count leaves that row off the card, which is the same as
        // a doctor nobody has consulted yet — better than showing a zero the
        // app is not sure about.
      }
    }
  }

  Future<void> _openDoctor(Doctor doctor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorDetailScreen(
          doctor: doctor,
          chatRepository: widget.chatRepository,
          doctorRepository: widget.repository,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      appBar: AppBar(
        title: const Text('ปรึกษาแพทย์'),
      ),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: doctors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return DoctorCard(
                doctor: doctor,
                consultCount: _consultCounts[doctor.id],
                onTap: () => _openDoctor(doctor),
              );
            },
          );
        },
      ),
    );
  }
}
