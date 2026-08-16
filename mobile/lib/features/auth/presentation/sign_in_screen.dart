import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_theme.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

/// Email/password against Supabase Auth, plus Google when the build carries
/// a GOOGLE_WEB_CLIENT_ID (see main.dart) — both against Supabase directly,
/// no server of this app's own in between.
///
/// Supabase requires confirming the address via an emailed link before a new
/// email/password account can sign in (see `_signUp`'s success message).
/// That's what stands in for phone verification here: it isn't optional, and
/// there is no server of this app's own to bypass it from. Google accounts
/// skip this — Google has already verified the address.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.notice, this.googleWebClientId});

  /// Shown when the user was sent here rather than arriving on their own —
  /// e.g. their session expired mid-use.
  final String? notice;

  /// Null when Google Sign-In hasn't been configured for this build — the
  /// Google button is hidden rather than shown broken.
  final String? googleWebClientId;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  bool _googleLoading = false;
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
    } catch (e) {
      setState(() => _error = friendlyError(e, whileDoing: t('เข้าสู่ระบบไม่สำเร็จ', 'Could not sign in')));
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
      _info = t('ส่งอีเมลยืนยันไปที่ $email แล้ว — เปิดอีเมลแล้วกดลิงก์ยืนยันก่อน จึงจะเข้าสู่ระบบได้', 'A confirmation email was sent to $email — follow the link in it before signing in');
    });
  }

  Future<void> _signInWithGoogle() async {
    final clientId = widget.googleWebClientId;
    if (clientId == null) return;

    setState(() {
      _googleLoading = true;
      _error = null;
      _info = null;
    });

    try {
      // serverClientId (the "Web application" OAuth client, not the Android
      // one) is what makes the returned idToken's audience match what
      // Supabase's Google provider validates against — see README for setup.
      final googleUser = await GoogleSignIn(serverClientId: clientId).signIn();
      if (googleUser == null) {
        // User closed the account picker — not an error worth showing.
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw StateError(
          t('Google ไม่ได้ส่ง idToken กลับมา — ตรวจสอบว่าตั้งค่า Web Client ID ถูกต้อง', 'Google returned no idToken — check that the Web Client ID is set correctly'),
        );
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      // Success updates app.dart's session listener — nothing more to do.
    } catch (e) {
      setState(() => _error = friendlyError(e, whileDoing: t('เข้าสู่ระบบด้วย Google ไม่สำเร็จ', 'Google sign-in failed')));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
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
                  'MediGo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: OnboardingColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? t('สมัครสมาชิกใหม่', 'Create an account') : t('เข้าสู่ระบบ', 'Sign in'),
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
                  decoration: _decoration(t('อีเมล', 'Email')),
                  validator: (v) => (v == null || !v.contains('@')) ? t('กรอกอีเมลให้ถูกต้อง', 'Enter a valid email') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _decoration(t('รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)', 'Password (at least 6 characters)')),
                  validator: (v) =>
                      (v == null || v.length < 6) ? t('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร', 'Password must be at least 6 characters') : null,
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
                            _isSignUp ? t('สมัครสมาชิก', 'Sign up') : t('เข้าสู่ระบบ', 'Sign in'),
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
                  child: Text(_isSignUp ? t('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ', 'Already have an account? Sign in') : t('ยังไม่มีบัญชี? สมัครสมาชิก', 'No account yet? Sign up')),
                ),
                if (widget.googleWebClientId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Divider(color: OnboardingColors.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          t('หรือ', 'or'),
                          style: TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
                        ),
                      ),
                      Expanded(child: Divider(color: OnboardingColors.border)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: (_loading || _googleLoading) ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: OnboardingColors.border),
                        foregroundColor: OnboardingColors.text,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _googleLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const _GoogleMark(),
                      label: Text(
                        t('เข้าสู่ระบบด้วย Google', 'Sign in with Google'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  t('การเข้าสู่ระบบถือว่าคุณยอมรับให้แอปเก็บข้อมูลสุขภาพ\nเพื่อใช้ติดตามการรักษาของคุณ', 'By signing in you agree to let the app store health information\nused to follow your treatment'),
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

/// Stand-in for Google's "G" mark — the project has no bundled brand asset,
/// so this draws a plain letter rather than pulling in an image dependency.
/// Swap for Google's official multi-color asset before shipping.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4285F4),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
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
