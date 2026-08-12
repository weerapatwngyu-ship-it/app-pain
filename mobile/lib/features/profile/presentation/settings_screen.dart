import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../reminders/presentation/notification_check_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Thai is the only language actually implemented today — this toggle is
  // a visual placeholder for a future localization pass, not wired to
  // anything yet.
  bool _englishSelected = false;

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์นี้อยู่ระหว่างการพัฒนา')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: 'ตั้งค่า',
              ),
              const SizedBox(height: 24),
              const Text('ตั้งค่า', style: TextStyle(color: OnboardingColors.textMuted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('ภาษา', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  _LanguageChip(
                    label: 'ภาษาไทย',
                    selected: !_englishSelected,
                    onTap: () => setState(() => _englishSelected = false),
                  ),
                  const SizedBox(width: 8),
                  _LanguageChip(
                    label: 'English',
                    selected: _englishSelected,
                    onTap: () => setState(() => _englishSelected = true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: OnboardingColors.border),
              _MenuRow(
                label: 'ตรวจสอบระบบเตือน',
                trailing: Icons.chevron_right,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationCheckScreen(),
                  ),
                ),
              ),
              _MenuRow(
                label: 'ตั้งค่าความเป็นส่วนตัว',
                trailing: Icons.lock_outline,
                onTap: _comingSoon,
              ),
              const SizedBox(height: 16),
              const Divider(color: OnboardingColors.border),
              const SizedBox(height: 12),
              const Text('นโยบาย', style: TextStyle(color: OnboardingColors.textMuted)),
              const SizedBox(height: 8),
              _MenuRow(
                label: 'นโยบายความเป็นส่วนตัว',
                trailing: Icons.chevron_right,
                onTap: _comingSoon,
              ),
              _MenuRow(
                label: 'ข้อตกลงและเงื่อนไข',
                trailing: Icons.chevron_right,
                onTap: _comingSoon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? OnboardingColors.teal.withOpacity(0.12) : null,
          border: Border.all(color: selected ? OnboardingColors.teal : OnboardingColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? OnboardingColors.teal : OnboardingColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.trailing, required this.onTap});

  final String label;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            Icon(trailing, color: OnboardingColors.textMuted),
          ],
        ),
      ),
    );
  }
}
