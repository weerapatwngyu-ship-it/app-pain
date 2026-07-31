import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'onboarding_theme.dart';
import 'pin_widgets.dart';

const _pinLength = 6;

/// PIN entry for a phone number that already has an account — reached
/// after OTP verification returns `isNewUser: false`.
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({
    super.key,
    required this.authRepository,
    required this.phone,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final String phone;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  void _onDigit(String digit) {
    if (_loading || _pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _onBackspace() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final session =
          await widget.authRepository.loginWithPhonePin(phone: widget.phone, pin: _pin);
      widget.onAuthenticated(session.user);
    } on ApiException catch (_) {
      setState(() {
        _error = 'รหัส PIN ไม่ถูกต้อง';
        _pin = '';
      });
    } on SocketException catch (_) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้';
        _pin = '';
      });
    } catch (e) {
      setState(() {
        _error = 'เข้าสู่ระบบไม่สำเร็จ: $e';
        _pin = '';
      });
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
              OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: 'กรอกรหัส PIN',
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 64),
                child: Text(
                  'กรอกรหัส PIN 6 หลักเพื่อเข้าสู่ระบบ',
                  style: TextStyle(color: OnboardingColors.textMuted),
                ),
              ),
              const SizedBox(height: 32),
              PinDots(length: _pinLength, filledCount: _pin.length),
              if (_loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            ],
          ),
        ),
      ),
    );
  }
}
