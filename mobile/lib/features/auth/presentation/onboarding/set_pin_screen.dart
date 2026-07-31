import 'package:flutter/material.dart';

import '../../domain/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'onboarding_theme.dart';
import 'personal_info_screen.dart';
import 'pin_widgets.dart';

const _pinLength = 6;

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({
    super.key,
    required this.authRepository,
    required this.phone,
    required this.consentHealth,
    required this.consentMarketing,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final String phone;
  final bool consentHealth;
  final bool consentMarketing;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool get _confirming => _pin.length == _pinLength;
  String? _error;

  void _onDigit(String digit) {
    setState(() {
      _error = null;
      if (!_confirming) {
        if (_pin.length < _pinLength) _pin += digit;
      } else {
        if (_confirmPin.length < _pinLength) _confirmPin += digit;
      }
    });
    if (_confirming && _confirmPin.length == _pinLength) _checkMatch();
  }

  void _onBackspace() {
    setState(() {
      _error = null;
      if (!_confirming) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _pin = '';
      _confirmPin = '';
      _error = null;
    });
  }

  void _checkMatch() {
    if (_confirmPin != _pin) {
      setState(() {
        _error = 'รหัส PIN ไม่ตรงกัน กรุณาลองใหม่';
        _confirmPin = '';
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalInfoScreen(
          authRepository: widget.authRepository,
          phone: widget.phone,
          consentHealth: widget.consentHealth,
          consentMarketing: widget.consentMarketing,
          pin: _pin,
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
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
                title: 'ตั้งรหัส PIN',
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 64),
                child: Text(
                  'ตั้งรหัส PIN 6 หลักเพื่อความปลอดภัยของบัญชีท่าน',
                  style: TextStyle(color: OnboardingColors.textMuted),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('สร้างรหัส PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                  if (_pin.isNotEmpty)
                    TextButton(onPressed: _reset, child: const Text('เริ่มใหม่')),
                ],
              ),
              const SizedBox(height: 8),
              PinDots(length: _pinLength, filledCount: _pin.length, active: !_confirming),
              const SizedBox(height: 24),
              const Text('ยืนยันรหัส PIN', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              PinDots(length: _pinLength, filledCount: _confirmPin.length, active: _confirming),
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
