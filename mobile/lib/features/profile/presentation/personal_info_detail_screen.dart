import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/patient_profile_repository.dart';
import '../domain/entities/patient_profile.dart';
import 'health_profile_screen.dart';
import 'personal_info_edit_screen.dart';
import '../../../core/i18n/app_locale.dart';

/// A getter, not a const map: the labels are translated, so they have to
/// be rebuilt after a language change rather than frozen at load.
Map<String, String> get _genderLabels => {
  'female': t('หญิง', 'Female'),
  'male': t('ชาย', 'Male'),
  'unspecified': t('ไม่ระบุ', 'Not specified'),
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
                  Expanded(
                    child: Text(
                      t('ข้อมูลส่วนตัว', 'Personal details'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: OnboardingColors.text,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openEdit,
                    child: Text(t('แก้ไข', 'Edit'), style: TextStyle(color: OnboardingColors.teal)),
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
                                t('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}', 'Could not load: ${snapshot.error}'),
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
    final foodAllergies = profile?.foodAllergies ?? const <String>[];
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
              Expanded(
                child: Text(
                  t('ข้อมูลสุขภาพ', 'Health information'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _user.patientId == null ? null : _openHealthEdit,
                child: Text(t('แก้ไข', 'Edit'),
                    style: TextStyle(color: OnboardingColors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _InfoRow(
            label: t('โรคประจำตัว', 'Ongoing conditions'),
            value: profile?.primaryCondition ?? '-',
          ),
          // Shown before the rest because it is the entry the app actually
          // acts on — it is checked against every medication being added.
          _chipList(
            label: t('ยาที่แพ้', 'Drug allergies'),
            values: allergies,
            background: const Color(0xFFFDECEC),
            border: const Color(0xFFF3B9B9),
          ),
          _chipList(
            label: t('อาหารที่แพ้', 'Food allergies'),
            values: foodAllergies,
            background: const Color(0xFFFFF4E5),
            border: const Color(0xFFF0D6A8),
          ),
          const Divider(color: OnboardingColors.border, height: 1),
          _InfoRow(label: t('กรุ๊ปเลือด', 'Blood type'), value: profile?.bloodType ?? '-'),
          _InfoRow(
            label: t('น้ำหนัก', 'Weight'),
            value: profile?.weightKg == null
                ? '-'
                : t('${_numberText(profile!.weightKg)} กก.', '${_numberText(profile!.weightKg)} kg'),
          ),
          _InfoRow(
            label: t('ส่วนสูง', 'Height'),
            value: profile?.heightCm == null
                ? '-'
                : t('${_numberText(profile!.heightCm)} ซม.', '${_numberText(profile!.heightCm)} cm'),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  /// One labelled row of allergy chips, or a dash when nothing is recorded.
  static Widget _chipList({
    required String label,
    required List<String> values,
    required Color background,
    required Color border,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: OnboardingColors.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          if (values.isEmpty)
            const Text('-',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in values)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.fromBorderSide(BorderSide(color: border)),
                    ),
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
              ],
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
            backgroundColor: Color(0xFF2D6CDF),
            child: Icon(Icons.person, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          _InfoRow(label: t('ชื่อจริง', 'First name'), value: _firstNameOf(_user)),
          _InfoRow(label: t('นามสกุล', 'Last name'), value: _lastNameOf(_user)),
          _InfoRow(label: t('เบอร์โทรศัพท์', 'Phone number'), value: _user.phone ?? '-'),
          _InfoRow(label: t('อีเมล', 'Email'), value: _user.email),
          _InfoRow(
            label: t('วันเกิด', 'Date of birth'),
            value: profile == null ? '-' : _formatBirthDate(profile.birthDate),
          ),
          _InfoRow(
            label: t('เพศสภาพ', 'Gender'),
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
