import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/patient_profile_repository.dart';
import '../domain/entities/patient_profile.dart';

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
  late final _emailController = TextEditingController(text: widget.user.email);
  DateTime? _birthDate;
  late String _gender = widget.profile?.gender ?? 'unspecified';
  bool _loading = false;
  String? _error;

  static const _genderOptions = {
    'female': 'หญิง',
    'male': 'ชาย',
    'unspecified': 'ไม่ระบุ',
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

  static String _firstNameOf(AppUser user) {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  static String _lastNameOf(AppUser user) {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
      final name = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
      final updatedUser = await widget.authRepository.updateProfile(
        name: name,
        email: _emailController.text.trim(),
      );

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
          ? 'อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว'
          : 'บันทึกไม่สำเร็จ: ${e.message}');
    } on SocketException catch (_) {
      setState(() => _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } catch (e) {
      setState(() => _error = 'บันทึกไม่สำเร็จ: $e');
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
                  title: 'แก้ไขข้อมูลส่วนตัว',
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  children: [
                    const Text('ชื่อจริง*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: _decoration('ชื่อจริง'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกชื่อจริง' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('นามสกุล*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: _decoration('นามสกุล'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกนามสกุล' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('อีเมล*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('example@mordee.com'),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'กรอกอีเมลให้ถูกต้อง' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('วันเกิด', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickBirthDate,
                      child: InputDecorator(
                        decoration: _decoration('วว/ดด/ปปปป'),
                        child: Text(
                          _birthDate == null ? 'วว/ดด/ปปปป' : _formatBirthDate(_birthDate!),
                          style: TextStyle(
                            color: _birthDate == null ? Colors.grey : OnboardingColors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('เพศสภาพ', style: TextStyle(fontWeight: FontWeight.w600)),
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
                                    selected ? OnboardingColors.teal.withOpacity(0.12) : null,
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
                  label: 'บันทึก',
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
