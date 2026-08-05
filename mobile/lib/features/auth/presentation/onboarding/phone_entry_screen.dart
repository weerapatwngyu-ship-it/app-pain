import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'onboarding_theme.dart';
import 'otp_verify_screen.dart';

/// Formats a 10-digit Thai phone number as the user types it: 0XX-XXX-XXXX.
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '').substring(
          0,
          newValue.text.replaceAll(RegExp(r'\D'), '').length > 10
              ? 10
              : newValue.text.replaceAll(RegExp(r'\D'), '').length,
        );
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
    this.notice,
  });

  final AuthRepository authRepository;
  final ValueChanged<AppUser> onAuthenticated;

  /// Shown above the form when the user was sent here rather than arriving
  /// on their own — e.g. their session expired mid-use.
  final String? notice;

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _digitsOnly => _phoneController.text.replaceAll('-', '');

  bool get _isValid => RegExp(r'^0\d{9}$').hasMatch(_digitsOnly);

  Future<void> _submit() async {
    if (!_isValid) {
      setState(() => _error = 'กรอกเบอร์โทรศัพท์ให้ครบ 10 หลัก');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.authRepository.requestOtp(phone: _digitsOnly);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            authRepository: widget.authRepository,
            phone: _digitsOnly,
            initialRefCode: result.refCode,
            initialExpiresInSeconds: result.expiresInSeconds,
            initialDevOtp: result.devOtp,
            onAuthenticated: widget.onAuthenticated,
          ),
        ),
      );
    } on SocketException catch (_) {
      setState(() => _error =
          'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ — ตรวจสอบว่า backend กำลังรันอยู่ และตั้งค่า MEDTRACK_API_BASE_URL ถูกต้อง');
    } on ApiException catch (e) {
      setState(() => _error = 'ขอรหัส OTP ไม่สำเร็จ (HTTP ${e.statusCode})');
    } catch (e) {
      setState(() => _error = 'ขอรหัส OTP ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'เข้าสู่ระบบ / ลงทะเบียน',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.text,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'เข้าสู่ระบบ หรือ ลงทะเบียนด้วยหมายเลขโทรศัพท์',
                style: TextStyle(fontSize: 16, color: OnboardingColors.textMuted),
              ),
              if (widget.notice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Color(0xFFB26A00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.notice!,
                          style: const TextStyle(fontSize: 14, color: Color(0xFFB26A00)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                maxLength: 12,
                style: const TextStyle(fontSize: 20),
                inputFormatters: [_PhoneFormatter()],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0XX-XXX-XXXX',
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: OnboardingColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: OnboardingColors.teal, width: 2),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              OnboardingPrimaryButton(
                label: 'ถัดไป',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider(color: OnboardingColors.border)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('หรือ', style: TextStyle(color: OnboardingColors.textMuted)),
                  ),
                  Expanded(child: Divider(color: OnboardingColors.border)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('การเข้าสู่ระบบด้วย Facebook ยังไม่รองรับ')),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OnboardingColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                  label: const Text(
                    'เข้าสู่ระบบด้วย Facebook',
                    style: TextStyle(color: OnboardingColors.text, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
