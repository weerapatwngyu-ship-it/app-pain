import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/patient_profile_repository.dart';
import '../domain/entities/patient_profile.dart';
import 'health_profile_screen.dart';
import 'personal_info_edit_screen.dart';
import '../../../shared/theme/app_palette.dart';

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

  /// Uses the stored given name, falling back to splitting the display name
  /// for accounts created before the two were kept apart. The split guesses —
  /// it treats everything after the first word as the surname — so it is only
  /// ever a fallback, never what a save writes back.
  String _firstNameOf(AppUser user) {
    final stored = user.firstName;
    if (stored != null) return stored;
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  String _lastNameOf(AppUser user) {
    final stored = user.lastName;
    if (stored != null) return stored;
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String _formatBirthDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Health details live on their own screen because that form validates
  /// measurements and keeps allergies as separate entries, which the plain
  /// personal-info form does not. It is reached from here rather than from
  /// its own row in the profile menu.
  Future<void> _openHealthEdit() async {
    final patientId = _user.patientId;
    if (patientId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthProfileScreen(
          patientId: patientId,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(_loadProfile);
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
      backgroundColor: AppPalette.tint,
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
      child: Column(
        children: [
          _buildIdentityCard(context, profile),
          const SizedBox(height: 16),
          _buildHealthCard(context, profile),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHealthCard(BuildContext context, PatientProfile? profile) {
    final allergies = profile?.drugAllergies ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ข้อมูลสุขภาพ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppPalette.heading),
                ),
              ),
              TextButton(
                onPressed: _user.patientId == null ? null : _openHealthEdit,
                child: const Text('แก้ไข',
                    style: TextStyle(color: OnboardingColors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _InfoRow(
            label: 'โรคประจำตัว',
            value: profile?.primaryCondition ?? '-',
          ),
          // Shown before the rest because it is the entry the app actually
          // acts on — it is checked against every medication being added.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ยาที่แพ้',
                    style: TextStyle(
                        color: OnboardingColors.textMuted, fontSize: 13)),
                const SizedBox(height: 6),
                if (allergies.isEmpty)
                  const Text('-',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final allergy in allergies)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.dangerSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: const Border.fromBorderSide(
                                BorderSide(color: AppPalette.dangerBorder)),
                          ),
                          child: Text(allergy,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(color: OnboardingColors.border, height: 1),
          _InfoRow(label: 'กรุ๊ปเลือด', value: profile?.bloodType ?? '-'),
          _InfoRow(
            label: 'น้ำหนัก',
            value: profile?.weightKg == null
                ? '-'
                : '${_numberText(profile!.weightKg)} กก.',
          ),
          _InfoRow(
            label: 'ส่วนสูง',
            value: profile?.heightCm == null
                ? '-'
                : '${_numberText(profile!.heightCm)} ซม.',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  /// Drops a trailing `.0` so a whole number reads as one.
  static String _numberText(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  Widget _buildIdentityCard(BuildContext context, PatientProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: AppPalette.primary,
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
            value: profile?.gender == null
                ? '-'
                : (_genderLabels[profile!.gender] ?? '-'),
            showDivider: false,
          ),
        ],
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
