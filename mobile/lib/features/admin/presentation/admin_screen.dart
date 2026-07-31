import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../data/admin_repository.dart';
import '../domain/entities/admin_summaries.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.adminRepository, required this.onLogout});

  final AdminRepository adminRepository;
  final VoidCallback onLogout;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _roleLabels = {
    'patient': 'ผู้ป่วย',
    'caregiver': 'ผู้ดูแล',
    'provider': 'บุคลากรทางการแพทย์',
    'admin': 'ผู้ดูแลระบบ',
  };

  late Future<List<AdminUserSummary>> _usersFuture;
  late Future<List<AdminPatientSummary>> _patientsFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = widget.adminRepository.listUsers();
    _patientsFuture = widget.adminRepository.listPatients();
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = widget.adminRepository.listUsers();
      _patientsFuture = widget.adminRepository.listPatients();
    });
    await Future.wait([_usersFuture, _patientsFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MedTrack — แอดมิน'),
          actions: [
            IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout), tooltip: 'ออกจากระบบ'),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'บัญชีผู้ใช้ทั้งหมด'),
              Tab(icon: Icon(Icons.badge_outlined), text: 'ผู้ป่วยทั้งหมด'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: TabBarView(
            children: [_buildUsersTab(), _buildPatientsTab()],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return FutureBuilder<List<AdminUserSummary>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('โหลดรายชื่อผู้ใช้ไม่สำเร็จ'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) return const Center(child: Text('ยังไม่มีผู้ใช้ในระบบ'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Chip(
                  label: Text(_roleLabels[user.role] ?? user.role),
                  backgroundColor: AppColors.accentSoft,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPatientsTab() {
    return FutureBuilder<List<AdminPatientSummary>>(
      future: _patientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('โหลดรายชื่อผู้ป่วยไม่สำเร็จ'));
        }
        final patients = snapshot.data ?? [];
        if (patients.isEmpty) return const Center(child: Text('ยังไม่มีผู้ป่วยในระบบ'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final patient = patients[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                title: Text(patient.name),
                subtitle: Text(
                  'เกิด ${patient.birthDate}'
                  '${patient.primaryCondition != null ? ' · ${patient.primaryCondition}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
