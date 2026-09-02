import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_theme.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

/// Resetting a forgotten password, start to finish, without leaving the app.
///
/// Supabase's own reset flow emails a link, and a link is useless here: this
/// build registers no deep link, so tapping it opens a browser that cannot
/// hand a session back to the app. What it can do instead is email a numeric
/// code — the same recovery token, in a form a person can type — which
/// `verifyOTP` exchanges for a session, and that session is what allows the
/// password to be changed.
///
/// Requires one line in the Supabase dashboard: the "Reset Password" email
/// template has to include {{ .Token }}. The default template only prints the
/// link, and a code that never arrives is worse than no button at all — see
/// README.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Carried over from the sign-in form so someone who has already typed
  /// their address does not type it again.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

/// Which half of the reset the screen is showing.
enum _Stage { enterEmail, enterCode }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// How long the emailed code may be.
  ///
  /// Not a fixed 6: the length is a project setting in Supabase (Authentication
  /// → Sign In / Providers → Email → Email OTP Length), which allows 6 to 10,
  /// and this project sends 8. Hardcoding 6 silently truncated the code as it
  /// was typed and then rejected it as the wrong length — a dead end with no
  /// hint of the cause. Accepting the whole allowed range means the screen
  /// keeps working if that setting is ever changed.
  static const _minCodeLength = 6;
  static const _maxCodeLength = 10;

  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Stage _stage = _Stage.enterEmail;
  bool _busy = false;
  String? _error;
  String? _info;

  /// True once the emailed code has been exchanged for a session. Kept so a
  /// failure while setting the password does not send the user back to
  /// re-enter a code that has already been spent — the session is live, and
  /// the next attempt only has to retry the password change.
  bool _codeAccepted = false;

  /// Seconds left before "send it again" is offered. Supabase rate-limits
  /// recovery emails, so offering the button immediately invites a refusal
  /// the user cannot interpret.
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail?.trim() ?? '';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  /// Sends the recovery email and moves on to the code step.
  ///
  /// The wording never changes with whether an account exists. Supabase
  /// deliberately succeeds either way, and saying "no account with that email"
  /// would turn this screen into a way of testing which addresses are
  /// registered — on an app whose users are patients.
  Future<void> _sendCode({bool resending = false}) async {
    if (!resending && !_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.enterCode;
        _info = t(
          'ถ้ามีบัญชีที่ใช้ $email อยู่ ระบบได้ส่งรหัสไปให้แล้ว — เปิดอีเมลแล้วนำรหัสมากรอก',
          'If an account uses $email, a code is on its way — open the email and enter it',
        );
      });
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e,
          whileDoing: t('ส่งรหัสไม่สำเร็จ', 'Could not send the code')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Exchanges the code for a session, then changes the password.
  Future<void> _setNewPassword() async {
    if (!_codeFormKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final auth = Supabase.instance.client.auth;
    // Both captured before the awaits below. Popping deactivates this
    // element, so looking either of them up off `context` afterwards reads
    // from a defunct tree — the snackbar would land nowhere, or throw.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!_codeAccepted) {
        await auth.verifyOTP(
          type: OtpType.recovery,
          email: _emailController.text.trim(),
          token: _codeController.text.trim(),
        );
        _codeAccepted = true;
      }

      await auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (!mounted) return;
      // verifyOTP already signed them in, so app.dart has swapped the screen
      // underneath this one. Popping lands them inside the app rather than
      // back at a sign-in form they no longer need.
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('ตั้งรหัสผ่านใหม่เรียบร้อยแล้ว',
              'Your new password is set')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e,
          whileDoing: t('ตั้งรหัสผ่านใหม่ไม่สำเร็จ',
              'Could not set the new password')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: t('ลืมรหัสผ่าน', 'Forgot password'),
              ),
              const SizedBox(height: 24),
              Text(
                _stage == _Stage.enterEmail
                    ? t('กรอกอีเมลที่ใช้สมัคร ระบบจะส่งรหัสยืนยันไปให้',
                        'Enter the email you signed up with and we will send a code')
                    : t('กรอกรหัสจากอีเมล แล้วตั้งรหัสผ่านใหม่',
                        'Enter the code from the email, then choose a new password'),
                style: const TextStyle(
                    fontSize: 14, height: 1.6, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 20),
              if (_info != null)
                _Banner(
                  text: _info!,
                  color: OnboardingColors.teal,
                  background: const Color(0xFFE8F5F3),
                ),
              if (_error != null)
                _Banner(
                  text: _error!,
                  color: const Color(0xFFC0392B),
                  background: const Color(0xFFFDECEA),
                ),
              const SizedBox(height: 8),
              if (_stage == _Stage.enterEmail) _buildEmailStep() else _buildCodeStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: _decoration(t('อีเมล', 'Email')),
            validator: (v) => (v == null || !v.contains('@'))
                ? t('กรอกอีเมลให้ถูกต้อง', 'Enter a valid email')
                : null,
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: t('ส่งรหัสยืนยัน', 'Send the code'),
            busy: _busy,
            onPressed: _busy ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            // The code is what stands between a stranger and this account, so
            // the field takes digits only rather than trusting a trim to
            // rescue whatever the keyboard produced.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_maxCodeLength),
            ],
            enabled: !_codeAccepted,
            style: const TextStyle(fontSize: 22, letterSpacing: 5),
            textAlign: TextAlign.center,
            decoration: _decoration(t('รหัสจากอีเมล', 'Code from the email')),
            validator: (v) {
              final code = v?.trim() ?? '';
              if (code.length < _minCodeLength || code.length > _maxCodeLength) {
                return t('กรอกรหัสจากอีเมลให้ครบทุกหลัก',
                    'Enter the whole code from the email');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _decoration(
                t('รหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)',
                    'New password (at least 6 characters)')),
            validator: (v) => (v == null || v.length < 6)
                ? t('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
                    'Password must be at least 6 characters')
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            decoration: _decoration(
                t('ยืนยันรหัสผ่านใหม่', 'Confirm the new password')),
            validator: (v) => v != _passwordController.text
                ? t('รหัสผ่านทั้งสองช่องไม่ตรงกัน', 'The two passwords do not match')
                : null,
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: t('ตั้งรหัสผ่านใหม่', 'Set the new password'),
            busy: _busy,
            onPressed: _busy ? null : _setNewPassword,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_busy || _resendIn > 0 || _codeAccepted)
                ? null
                : () => _sendCode(resending: true),
            child: Text(
              _resendIn > 0
                  ? t('ขอรหัสใหม่ได้ในอีก $_resendIn วินาที',
                      'You can ask for another code in $_resendIn seconds')
                  : t('ไม่ได้รับรหัส? ส่งอีกครั้ง',
                      "Didn't get the code? Send it again"),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _stage = _Stage.enterEmail;
                      _codeAccepted = false;
                      _codeController.clear();
                      _error = null;
                      _info = null;
                    }),
            child: Text(t('ใช้อีเมลอื่น', 'Use a different email')),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 15, letterSpacing: 0, color: OnboardingColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: OnboardingColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: OnboardingColors.border),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: OnboardingColors.teal,
          disabledBackgroundColor: OnboardingColors.tealDisabled,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.6, color: color),
      ),
    );
  }
}
