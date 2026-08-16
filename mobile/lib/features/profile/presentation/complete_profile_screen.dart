import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../../shared/widgets/avatar_picker.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../../shared/validation/thai_phone.dart';
import '../data/patient_profile_repository.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

/// The form a new member fills in once, straight after signing up.
///
/// Sign-up only establishes an identity: the trigger behind it can do no
/// better than an email-derived name and a placeholder birth date, because
/// neither is something an email address contains. Everything the app shows
/// about a person is entered here.
///
/// There is deliberately no skip. A birth date left at its placeholder is
/// worse than one that is missing — it reads as real everywhere it appears,
/// and on a medication app a wrong age is the kind of wrong that reaches a
/// dose. Sign-out is offered instead, so nobody is trapped.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.user,
    required this.authRepository,
    required this.patientProfileRepository,
    required this.onCompleted,
    required this.onLogout,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final PatientProfileRepository patientProfileRepository;
  final ValueChanged<AppUser> onCompleted;
  final VoidCallback onLogout;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _firstNameController = TextEditingController(text: widget.user.firstName ?? '');
  late final _lastNameController = TextEditingController(text: widget.user.lastName ?? '');
  late final _phoneController = TextEditingController(text: widget.user.phone ?? '');
  late final _emailController = TextEditingController(text: widget.user.email);

  DateTime? _birthDate;
  String _gender = 'unspecified';
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;

  /// Held here rather than read from widget.user, because the upload happens
  /// while this form is still open and the parent has not been told yet.
  late AppUser _user = widget.user;

  /// A getter, not a const map: the labels are translated, so they have
  /// to be rebuilt after a language change rather than frozen at load.
  static Map<String, String> get _genderOptions => {
    'female': t('หญิง', 'Female'),
    'male': t('ชาย', 'Male'),
    'unspecified': t('ไม่ระบุ', 'Not specified'),
  };

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
      helpText: t('เลือกวันเกิด', 'Choose date of birth'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  /// The photo uploads immediately rather than waiting for the save, because
  /// uploading is what the backend offers — there is no way to hold bytes
  /// pending alongside a row update. Backing out of the form after choosing
  /// one therefore keeps the photo, which is the harmless direction to err.
  Future<void> _changeAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final updated = await pickAndUploadAvatar(
        context: context,
        authRepository: widget.authRepository,
      );
      if (updated != null && mounted) setState(() => _user = updated);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _formatBirthDate(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // The date picker is not a form field, so its own error has to be raised
    // by hand rather than by the validator run above.
    if (_birthDate == null) {
      setState(() => _error = t('กรุณาเลือกวันเกิด', 'Choose your date of birth'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      final user = await widget.authRepository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        markCompleted: true,
      );

      // The patient record carries the medical fields and is what every
      // patient-scoped screen reads, so the name is written to both.
      if (user.patientId != null) {
        await widget.patientProfileRepository.update(
          user.patientId!,
          name: user.name,
          birthDate: '${_birthDate!.year}-${_two(_birthDate!.month)}-${_two(_birthDate!.day)}',
          gender: _gender,
        );
      }

      if (!mounted) return;
      widget.onCompleted(user);
    } on PostgrestException catch (e) {
      // 23505 is Postgres' unique-violation code, which here can only be the
      // email already being on another account.
      setState(() => _error = e.code == '23505'
          ? t('อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว', 'That email is already registered')
          : t('บันทึกไม่สำเร็จ: ${e.message}', 'Could not save: ${e.message}'));
    } on SocketException catch (_) {
      setState(() => _error = t('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่อีกครั้ง', 'Cannot reach the server. Try again.'));
    } catch (e) {
      setState(() => _error = friendlyError(e, whileDoing: t('บันทึกไม่สำเร็จ', 'Could not save')));
    } finally {
      if (mounted) setState(() => _saving = false);
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('กรอกข้อมูลส่วนตัว', 'Your details'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : widget.onLogout,
                      child: Text(t('ออกจากระบบ', 'Sign out')),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t('กรอกครั้งเดียว แก้ไขภายหลังได้ที่โปรไฟล์', 'Once only — you can change these later in your profile'),
                    style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          UserAvatar(
                            // The initial is only a stand-in until a photo is
                            // chosen, so it reads the saved name rather than
                            // the field being typed into — following the field
                            // would need a listener to earn a letter nobody is
                            // looking at.
                            name: _user.name,
                            avatarUrl: _user.avatarUrl,
                            radius: 44,
                            onTap: _saving ? null : _changeAvatar,
                            loading: _uploadingAvatar,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t('แตะเพื่อใส่รูปโปรไฟล์', 'Tap to add a profile photo'),
                            style: const TextStyle(
                              color: OnboardingColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Label(t('ชื่อจริง*', 'First name*')),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(t('ชื่อจริง', 'First name')),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? t('กรอกชื่อจริง', 'Enter your first name') : null,
                    ),
                    const SizedBox(height: 16),
                    _Label(t('นามสกุล*', 'Last name*')),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(t('นามสกุล', 'Last name')),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? t('กรอกนามสกุล', 'Enter your last name') : null,
                    ),
                    const SizedBox(height: 16),
                    _Label(t('เบอร์โทรศัพท์*', 'Phone number*')),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration('08xxxxxxxx'),
                      validator: validateThaiPhone,
                    ),
                    const SizedBox(height: 16),
                    _Label(t('อีเมล*', 'Email*')),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('example@email.com'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? t('กรอกอีเมลให้ถูกต้อง', 'Enter a valid email')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _Label(t('วันเกิด*', 'Date of birth*')),
                    InkWell(
                      onTap: _saving ? null : _pickBirthDate,
                      child: InputDecorator(
                        decoration: _decoration(t('วว/ดด/ปปปป', 'DD/MM/YYYY')),
                        child: Text(
                          _birthDate == null
                              ? t('วว/ดด/ปปปป', 'DD/MM/YYYY')
                              : _formatBirthDate(_birthDate!),
                          style: TextStyle(
                            color: _birthDate == null
                                ? Colors.grey
                                : OnboardingColors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Label(t('เพศ', 'Gender')),
                    Row(
                      children: _genderOptions.entries.map((entry) {
                        final selected = _gender == entry.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              onPressed: () => setState(() => _gender = entry.key),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: selected
                                    ? OnboardingColors.teal.withValues(alpha: 0.12)
                                    : null,
                                side: BorderSide(
                                  color: selected
                                      ? OnboardingColors.teal
                                      : OnboardingColors.border,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: selected
                                      ? OnboardingColors.teal
                                      : OnboardingColors.text,
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
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: OnboardingPrimaryButton(
                  label: t('บันทึกและเริ่มใช้งาน', 'Save and get started'),
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
