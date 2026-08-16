import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../../shared/validation/thai_phone.dart';
import '../data/patient_profile_repository.dart';
import '../domain/entities/patient_profile.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

class PersonalInfoEditScreen extends StatefulWidget {
  const PersonalInfoEditScreen({
    super.key,
    required this.user,
    required this.profile,
    required this.authRepository,
    required this.patientProfileRepository,
  });

  final AppUser user;
  final PatientProfile? profile;
  final AuthRepository authRepository;
  final PatientProfileRepository patientProfileRepository;

  @override
  State<PersonalInfoEditScreen> createState() => _PersonalInfoEditScreenState();
}

class _PersonalInfoEditScreenState extends State<PersonalInfoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(text: _firstNameOf(widget.user));
  late final _lastNameController = TextEditingController(text: _lastNameOf(widget.user));
  late final _phoneController = TextEditingController(text: widget.user.phone ?? '');
  late final _emailController = TextEditingController(text: widget.user.email);
  DateTime? _birthDate;
  late String _gender = widget.profile?.gender ?? 'unspecified';
  bool _loading = false;
  String? _error;

  /// A getter, not a const map: the labels are translated, so they have
  /// to be rebuilt after a language change rather than frozen at load.
  static Map<String, String> get _genderOptions => {
    'female': t('หญิง', 'Female'),
    'male': t('ชาย', 'Male'),
    'unspecified': t('ไม่ระบุ', 'Not specified'),
  };

  @override
  void initState() {
    super.initState();
    final birthDate = widget.profile?.birthDate;
    if (birthDate != null) {
      final parts = birthDate.split('-');
      if (parts.length == 3) {
        _birthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    }
  }

  /// Prefers the stored given name and only falls back to splitting the
  /// display name for accounts created before the two were kept apart.
  /// The split is a guess — it puts every part after the first into the
  /// surname — which is why it is not what gets saved back.
  static String _firstNameOf(AppUser user) {
    final stored = user.firstName;
    if (stored != null) return stored;
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  static String _lastNameOf(AppUser user) {
    final stored = user.lastName;
    if (stored != null) return stored;
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatBirthDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final updatedUser = await widget.authRepository.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      final name = updatedUser.name;

      PatientProfile? updatedProfile;
      if (updatedUser.patientId != null) {
        String? isoBirthDate;
        if (_birthDate != null) {
          String two(int n) => n.toString().padLeft(2, '0');
          isoBirthDate = '${_birthDate!.year}-${two(_birthDate!.month)}-${two(_birthDate!.day)}';
        }
        updatedProfile = await widget.patientProfileRepository.update(
          updatedUser.patientId!,
          name: name,
          birthDate: isoBirthDate,
          gender: _gender,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop((updatedUser, updatedProfile));
    } on PostgrestException catch (e) {
      // 23505 is Postgres' unique-violation code; here that means the email
      // is already on another account.
      setState(() => _error = e.code == '23505'
          ? t('อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว', 'That email is already registered')
          : t('บันทึกไม่สำเร็จ: ${e.message}', 'Could not save: ${e.message}'));
    } on SocketException catch (_) {
      setState(() => _error = t('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', 'Cannot reach the server'));
    } catch (e) {
      setState(() => _error = friendlyError(e, whileDoing: t('บันทึกไม่สำเร็จ', 'Could not save')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: OnboardingHeader(
                  icon: Icons.arrow_back,
                  onIconTap: () => Navigator.of(context).pop(),
                  title: t('แก้ไขข้อมูลส่วนตัว', 'Edit personal details'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  children: [
                    Text(t('ชื่อจริง*', 'First name*'), style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: _decoration(t('ชื่อจริง', 'First name')),
                      validator: (v) => (v == null || v.trim().isEmpty) ? t('กรอกชื่อจริง', 'Enter your first name') : null,
                    ),
                    const SizedBox(height: 16),
                    Text(t('นามสกุล*', 'Last name*'), style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: _decoration(t('นามสกุล', 'Last name')),
                      validator: (v) => (v == null || v.trim().isEmpty) ? t('กรอกนามสกุล', 'Enter your last name') : null,
                    ),
                    const SizedBox(height: 16),
                    Text(t('เบอร์โทรศัพท์*', 'Phone number*'), style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration('08xxxxxxxx'),
                      validator: validateThaiPhone,
                    ),
                    const SizedBox(height: 16),
                    Text(t('อีเมล*', 'Email*'), style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('example@mordee.com'),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? t('กรอกอีเมลให้ถูกต้อง', 'Enter a valid email') : null,
                    ),
                    const SizedBox(height: 16),
                    Text(t('วันเกิด', 'Date of birth'), style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickBirthDate,
                      child: InputDecorator(
                        decoration: _decoration(t('วว/ดด/ปปปป', 'DD/MM/YYYY')),
                        child: Text(
                          _birthDate == null ? t('วว/ดด/ปปปป', 'DD/MM/YYYY') : _formatBirthDate(_birthDate!),
                          style: TextStyle(
                            color: _birthDate == null ? Colors.grey : OnboardingColors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(t('เพศสภาพ', 'Gender'), style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: _genderOptions.entries.map((entry) {
                        final selected = _gender == entry.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              onPressed: () => setState(() => _gender = entry.key),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    selected ? OnboardingColors.teal.withValues(alpha: 0.12) : null,
                                side: BorderSide(
                                  color: selected ? OnboardingColors.teal : OnboardingColors.border,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape:
                                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: selected ? OnboardingColors.teal : OnboardingColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: OnboardingPrimaryButton(
                  label: t('บันทึก', 'Save'),
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
