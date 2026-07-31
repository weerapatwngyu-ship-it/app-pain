import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'consent_screen.dart';
import 'onboarding_theme.dart';
import 'otp_box_row.dart';
import 'pin_login_screen.dart';

const _otpLength = 6;

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.authRepository,
    required this.phone,
    required this.initialRefCode,
    required this.initialExpiresInSeconds,
    required this.onAuthenticated,
    this.initialDevOtp,
  });

  final AuthRepository authRepository;
  final String phone;
  final String initialRefCode;
  final int initialExpiresInSeconds;
  final String? initialDevOtp;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _boxKey = GlobalKey<OtpBoxRowState>();
  Timer? _timer;
  // `late` is required here, not just a nicety — `widget` isn't set yet
  // during State field-initializer evaluation, only from initState() on.
  late String _refCode = widget.initialRefCode;
  late String? _devOtp = widget.initialDevOtp;
  late int _secondsLeft = widget.initialExpiresInSeconds;
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.authRepository.verifyOtp(phone: widget.phone, otp: code);
      if (!mounted) return;
      if (result.isNewUser) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConsentScreen(
              authRepository: widget.authRepository,
              phone: widget.phone,
              onAuthenticated: widget.onAuthenticated,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PinLoginScreen(
              authRepository: widget.authRepository,
              phone: widget.phone,
              onAuthenticated: widget.onAuthenticated,
            ),
          ),
        );
      }
    } on ApiException catch (_) {
      setState(() => _error = 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ');
      _boxKey.currentState?.clear();
    } on SocketException catch (_) {
      setState(() => _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } catch (e) {
      setState(() => _error = 'ยืนยัน OTP ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final result = await widget.authRepository.requestOtp(phone: widget.phone);
      setState(() {
        _refCode = result.refCode;
        _devOtp = result.devOtp;
        _secondsLeft = result.expiresInSeconds;
      });
      _boxKey.currentState?.clear();
      _startTimer();
    } catch (_) {
      setState(() => _error = 'ส่งรหัส OTP อีกครั้งไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_resending;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: 'เข้าสู่ระบบ / ลงทะเบียน',
              ),
              const SizedBox(height: 32),
              const Text(
                'ใส่รหัส OTP ที่ได้รับทาง SMS\nเพื่อยืนยันเบอร์โทรศัพท์',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Ref code : $_refCode'),
                ),
              ),
              const SizedBox(height: 32),
              OtpBoxRow(key: _boxKey, length: _otpLength, onCompleted: _verify),
              if (_devOtp != null) ...[
                const SizedBox(height: 16),
                Text(
                  'โหมดทดสอบ (ไม่มี SMS gateway จริง) — รหัส OTP คือ $_devOtp',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 40),
              Center(
                child: TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    'ส่งรหัส OTP อีกครั้ง',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: canResend ? OnboardingColors.text : OnboardingColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (!canResend)
                Center(
                  child: Text(
                    'ขอรหัส PIN ใหม่อีกครั้งในอีก $_secondsLeft วินาที',
                    style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
