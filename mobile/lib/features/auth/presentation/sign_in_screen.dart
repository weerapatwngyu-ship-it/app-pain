import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_theme.dart';

/// Email/password against Supabase Auth — no external provider, no OAuth
/// redirect, nothing to configure outside the Supabase dashboard.
///
/// Supabase requires confirming the address via an emailed link before a
/// new account can sign in (see `_signUp`'s success message). That's what
/// stands in for phone verification here: it isn't optional, and there is
/// no server of this app's own to bypass it from.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.notice});

  /// Shown when the user was sent here rather than arriving on their own —
  /// e.g. their session expired mid-use.
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        await _signUp(email, password);
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // Success updates app.dart's session listener — nothing more to do.
      }
    } on AuthException catch (e) {
      setState(() => _error = _readableAuthError(e));
    } catch (e) {
      setState(() => _error = 'เข้าสู่ระบบไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp(String email, String password) async {
    final result = await Supabase.instance.client.auth.signUp(email: email, password: password);
    if (!mounted) return;

    if (result.session != null) {
      // Email confirmation is off for this project — signed in immediately.
      return;
    }

    // Confirmation required: nothing to do but tell the user to check their
    // inbox, then switch them to the sign-in form for after they click it.
    setState(() {
      _isSignUp = false;
      _info = 'ส่งอีเมลยืนยันไปที่ $email แล้ว — เปิดอีเมลแล้วกดลิงก์ยืนยันก่อน จึงจะเข้าสู่ระบบได้';
    });
  }

  String _readableAuthError(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'User already registered':
        return 'อีเมลนี้สมัครไว้แล้ว — ลองเข้าสู่ระบบแทน';
      case 'Email not confirmed':
        return 'ยังไม่ได้ยืนยันอีเมล — เปิดอีเมลแล้วกดลิงก์ยืนยันก่อน';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.medical_services, size: 64, color: OnboardingColors.teal),
                const SizedBox(height: 16),
                const Text(
                  'MedTrack',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: OnboardingColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? 'สมัครสมาชิกใหม่' : 'เข้าสู่ระบบ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: OnboardingColors.textMuted),
                ),
                if (widget.notice != null) _Banner(text: widget.notice!, color: const Color(0xFFB26A00), background: const Color(0xFFFFF4E5)),
                if (_info != null) _Banner(text: _info!, color: OnboardingColors.teal, background: const Color(0xFFE8F5F3)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _decoration('อีเมล'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'กรอกอีเมลให้ถูกต้อง' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _decoration('รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)'),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OnboardingColors.teal,
                      disabledBackgroundColor: OnboardingColors.tealDisabled,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                            _info = null;
                          }),
                  child: Text(_isSignUp ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สมัครสมาชิก'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'การเข้าสู่ระบบถือว่าคุณยอมรับให้แอปเก็บข้อมูลสุขภาพ\nเพื่อใช้ติดตามการรักษาของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: color))),
          ],
        ),
      ),
    );
  }
}
