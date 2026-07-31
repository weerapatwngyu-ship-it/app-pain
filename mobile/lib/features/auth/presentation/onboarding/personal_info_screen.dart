import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'account_created_screen.dart';
import 'onboarding_theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({
    super.key,
    required this.authRepository,
    required this.phone,
    required this.consentHealth,
    required this.consentMarketing,
    required this.pin,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final String phone;
  final bool consentHealth;
  final bool consentMarketing;
  final String pin;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'unspecified';
  bool _loading = false;
  String? _error;

  static const _genderOptions = {
    'female': 'หญิง',
    'male': 'ชาย',
    'unspecified': 'ไม่ระบุ',
  };

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
      initialDate: DateTime(now.year - 25),
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
    if (_birthDate == null) {
      setState(() => _error = 'กรุณาเลือกวันเกิด');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String two(int n) => n.toString().padLeft(2, '0');
      final isoBirthDate =
          '${_birthDate!.year}-${two(_birthDate!.month)}-${two(_birthDate!.day)}';
      final session = await widget.authRepository.registerWithPhone(
        phone: widget.phone,
        pin: widget.pin,
        consentHealth: widget.consentHealth,
        consentMarketing: widget.consentMarketing,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        birthDate: isoBirthDate,
        gender: _gender,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AccountCreatedScreen(
            onStart: () => widget.onAuthenticated(session.user),
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.statusCode == 409
          ? 'เบอร์โทรศัพท์หรืออีเมลนี้ถูกใช้สมัครสมาชิกแล้ว'
          : 'สร้างบัญชีไม่สำเร็จ (HTTP ${e.statusCode})');
    } on SocketException catch (_) {
      setState(() => _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } catch (e) {
      setState(() => _error = 'สร้างบัญชีไม่สำเร็จ: $e');
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  children: [
                    const Text(
                      'ข้อมูลส่วนตัว',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: OnboardingColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'กรุณากรอกข้อมูลเพื่อเป็นประโยชน์สำหรับแพทย์และเอกสารทางการแพทย์ของท่าน',
                      style: TextStyle(color: OnboardingColors.textMuted),
                    ),
                    const SizedBox(height: 24),
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
                    const Text('เบอร์โทรศัพท์*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: widget.phone,
                      enabled: false,
                      decoration: _decoration(widget.phone),
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
                    const SizedBox(height: 4),
                    const Text(
                      'ท่านสามารถรับข่าวสาร และกู้คืนบัญชีของท่านผ่านทางอีเมลนี้',
                      style: TextStyle(color: OnboardingColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text('วันเกิด*', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    const SizedBox(height: 4),
                    const Text(
                      'กรุณาระบุปีเกิดเป็น ค.ศ.',
                      style: TextStyle(color: OnboardingColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text('เพศสภาพ*', style: TextStyle(fontWeight: FontWeight.w600)),
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: OnboardingPrimaryButton(
                  label: 'ดำเนินการต่อ',
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
