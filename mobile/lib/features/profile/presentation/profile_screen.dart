import 'package:flutter/material.dart';

import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  /// Short, human-friendly stand-in for a "member code" — derived from the
  /// account's real id (not fabricated), since the backend doesn't hand out
  /// a separate short code today.
  String get _userCode => user.id.replaceAll('-', '').substring(0, 6).toUpperCase();

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์นี้อยู่ระหว่างการพัฒนา')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: OnboardingColors.teal,
                  child: Text(
                    user.name.trim().isEmpty ? '?' : user.name.trim()[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'รหัสผู้ใช้งาน: $_userCode',
                        style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                OnboardingIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OnboardingPrimaryButton(
              label: '+  เพิ่มสิทธิพิเศษ/กรมธรรม์',
              onPressed: () => _comingSoon(context),
            ),
            const SizedBox(height: 24),
            _SectionLabel('บัญชีผู้ใช้'),
            _MenuTile(
              icon: Icons.person_outline,
              label: 'แก้ไขข้อมูลส่วนตัว',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.favorite_border,
              label: 'ข้อมูลสุขภาพ',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.payments_outlined,
              label: 'การชำระเงิน',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.local_shipping_outlined,
              label: 'ข้อมูลการจัดส่งสินค้า',
              onTap: () => _comingSoon(context),
            ),
            const SizedBox(height: 16),
            _SectionLabel('ช่วยเหลือ'),
            _MenuTile(
              icon: Icons.headset_mic_outlined,
              label: 'ติดต่อเจ้าหน้าที่ทาง Line App',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.help_outline,
              label: 'คำถามที่พบบ่อย',
              onTap: () => _comingSoon(context),
            ),
            _MenuTile(
              icon: Icons.menu_book_outlined,
              label: 'คู่มือการใช้งาน',
              onTap: () => _comingSoon(context),
            ),
            const SizedBox(height: 16),
            _SectionLabel('อื่นๆ'),
            _MenuTile(
              icon: Icons.logout,
              label: 'ออกจากระบบ',
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: OnboardingColors.textMuted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            Icon(icon, color: OnboardingColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
