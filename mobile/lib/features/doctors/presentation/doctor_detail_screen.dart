import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/doctor_repository.dart';
import '../domain/entities/doctor.dart';
import 'doctor_form_screen.dart';

class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({
    super.key,
    required this.doctor,
    required this.repository,
  });

  final Doctor doctor;
  final DoctorRepository repository;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  late Doctor _doctor;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Doctor>(
      MaterialPageRoute(
        builder: (_) => DoctorFormScreen(
          repository: widget.repository,
          doctor: _doctor,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _doctor = updated);
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _doctor.photoUrl != null ? _doctor.photoUrl! : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์แพทย์'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'แก้ไขข้อมูล', onPressed: _edit),
        ],
      ),
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
            _doctor.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _doctor.specialty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OnboardingColors.teal, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (_doctor.bio != null && _doctor.bio!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('ข้อมูลเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_doctor.bio!, style: const TextStyle(height: 1.5)),
          ],
        ],
      ),
    );
  }
}
