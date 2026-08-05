import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_theme.dart';

/// Sign-in is a single tap: Supabase Auth hands the Google flow off to the
/// browser and returns to the app through the deep link registered in the
/// Android manifest. This app never sees a password, and identity
/// verification is Google's job rather than a homegrown OTP.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.notice});

  /// Shown when the user was sent here rather than arriving on their own —
  /// e.g. their session expired mid-use.
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.medtrack://login-callback',
      );
      // The browser now owns the flow. Completion arrives as an auth state
      // change on the deep link, which app.dart is listening for, so there
      // is nothing to await here.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'เข้าสู่ระบบไม่สำเร็จ: $e');
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
              const Spacer(),
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
              const Text(
                'ติดตามการกินยาและอาการของคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: OnboardingColors.textMuted),
              ),
              if (widget.notice != null) ...[
                const SizedBox(height: 24),
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
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              _GoogleSignInButton(onPressed: _loading ? null : _signInWithGoogle, loading: _loading),
              const SizedBox(height: 16),
              const Text(
                'การเข้าสู่ระบบถือว่าคุณยอมรับให้แอปเก็บข้อมูลสุขภาพ\nเพื่อใช้ติดตามการรักษาของคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: OnboardingColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: OnboardingColors.text,
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_circle, size: 22, color: Color(0xFF4285F4)),
                  SizedBox(width: 12),
                  Text(
                    'เข้าสู่ระบบด้วย Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}
