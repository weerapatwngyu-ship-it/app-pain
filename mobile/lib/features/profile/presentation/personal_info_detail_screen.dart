import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/patient_profile_repository.dart';
import '../domain/entities/patient_profile.dart';
import 'personal_info_edit_screen.dart';

const _genderLabels = {
  'female': 'หญิง',
  'male': 'ชาย',
  'unspecified': 'ไม่ระบุ',
};

class PersonalInfoDetailScreen extends StatefulWidget {
  const PersonalInfoDetailScreen({
    super.key,
    required this.user,
    required this.authRepository,
    required this.repository,
    required this.onUserUpdated,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final PatientProfileRepository repository;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<PersonalInfoDetailScreen> createState() => _PersonalInfoDetailScreenState();
}

class _PersonalInfoDetailScreenState extends State<PersonalInfoDetailScreen> {
  late AppUser _user = widget.user;
  PatientProfile? _profile;
  Future<PatientProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = _user.patientId != null ? widget.repository.fetch(_user.patientId!) : null;
  }

  String _firstNameOf(AppUser user) {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  String _lastNameOf(AppUser user) {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String _formatBirthDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<(AppUser, PatientProfile?)>(
      MaterialPageRoute(
        builder: (_) => PersonalInfoEditScreen(
          user: _user,
          profile: _profile,
          authRepository: widget.authRepository,
          patientProfileRepository: widget.repository,
        ),
      ),
    );
    if (result == null) return;
    final (updatedUser, updatedProfile) = result;
    widget.onUserUpdated(updatedUser);
    setState(() {
      _user = updatedUser;
      _profile = updatedProfile;
      _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  OnboardingIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'ข้อมูลส่วนตัว',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: OnboardingColors.text,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openEdit,
                    child: const Text('แก้ไข', style: TextStyle(color: OnboardingColors.teal)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _profileFuture == null
                    ? _buildCard(context, null)
                    : FutureBuilder<PatientProfile>(
                        future: _profileFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          _profile = snapshot.data;
                          return _buildCard(context, snapshot.data);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, PatientProfile? profile) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFF2D6CDF),
              child: Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            _InfoRow(label: 'ชื่อจริง', value: _firstNameOf(_user)),
            _InfoRow(label: 'นามสกุล', value: _lastNameOf(_user)),
            _InfoRow(label: 'เบอร์โทรศัพท์', value: _user.phone ?? '-'),
            _InfoRow(label: 'อีเมล', value: _user.email),
            _InfoRow(
              label: 'วันเกิด',
              value: profile == null ? '-' : _formatBirthDate(profile.birthDate),
            ),
            _InfoRow(
              label: 'เพศสภาพ',
              value: profile?.gender == null ? '-' : (_genderLabels[profile!.gender] ?? '-'),
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.showDivider = true});

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(color: OnboardingColors.border, height: 1),
      ],
    );
  }
}
