import 'package:flutter/material.dart';

import 'onboarding_theme.dart';

class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'สร้างบัญชี',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: OnboardingColors.text),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: OnboardingColors.teal, size: 120),
                        SizedBox(height: 24),
                        Text(
                          'สร้างบัญชีเรียบร้อย',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: OnboardingColors.teal,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'คุณสามารถเข้าสู่ระบบ MedTrack ได้ด้วยบัญชีนี้',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: OnboardingColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                OnboardingPrimaryButton(label: 'เริ่มต้นใช้งาน', onPressed: onStart),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
