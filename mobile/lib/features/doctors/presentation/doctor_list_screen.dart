import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/doctor_repository.dart';
import '../domain/entities/doctor.dart';
import 'doctor_detail_screen.dart';
import 'doctor_form_screen.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key, required this.repository});

  final DoctorRepository repository;

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

  void _reload() {
    setState(() => _doctorsFuture = widget.repository.fetchAll());
  }

  Future<void> _openDoctor(Doctor doctor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorDetailScreen(
          doctor: doctor,
          repository: widget.repository,
        ),
      ),
    );
    _reload();
  }

  Future<void> _addDoctor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorFormScreen(repository: widget.repository),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ปรึกษาแพทย์')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDoctor,
        backgroundColor: OnboardingColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
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
          final doctors = snapshot.data ?? [];
          if (doctors.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลแพทย์ กด + เพื่อเพิ่ม'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            separatorBuilder: (_, __) => const Divider(color: OnboardingColors.border),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              final photoUrl = doctor.photoUrl != null ? doctor.photoUrl! : null;
              return ListTile(
                onTap: () => _openDoctor(doctor),
                leading: CircleAvatar(
                  backgroundColor: OnboardingColors.teal,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.medical_services_outlined, color: Colors.white, size: 20)
                      : null,
                ),
                title: Text(doctor.name),
                subtitle: Text(doctor.specialty),
                trailing: const Icon(Icons.chevron_right),
              );
            },
          );
        },
      ),
    );
  }
}
