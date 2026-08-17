import 'package:flutter/material.dart';

import '../../../core/i18n/app_locale.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../peer_chat/data/peer_chat_repository.dart';
import '../data/privacy_repository.dart';
import '../domain/legal_documents.dart';
import 'legal_document_screen.dart';
import 'privacy_settings_screen.dart';
import '../../reminders/presentation/notification_check_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.patientId,
    this.peerChatRepository,
  });

  /// Null for an account with no patient record — a doctor or an admin. The
  /// privacy controls are about a patient's own record, so the row is left out
  /// rather than opening a screen with nothing on it.
  final String? patientId;
  final PeerChatRepository? peerChatRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Applies immediately and everywhere: the root of the app listens to the
  /// controller, so the screen behind this one is already in the new language
  /// by the time the user goes back to it.
  Future<void> _setLocale(AppLocale locale) async {
    await LocaleController.instance.set(locale);
    if (mounted) setState(() {});
  }

  /// Built here rather than passed in: it holds no state and takes no
  /// dependencies, so threading one more object through four widgets to reach
  /// this screen would buy nothing.
  final PrivacyRepository _privacyRepository = PrivacyRepository();

  bool get _canManagePrivacy =>
      widget.patientId != null && widget.peerChatRepository != null;

  void _openPrivacySettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivacySettingsScreen(
          patientId: widget.patientId!,
          repository: _privacyRepository,
          peerChatRepository: widget.peerChatRepository!,
        ),
      ),
    );
  }

  void _openDocument(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(document: document)),
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
                title: t('ตั้งค่า', 'Settings'),
              ),
              const SizedBox(height: 24),
              Text(t('ทั่วไป', 'General'),
                  style: const TextStyle(color: OnboardingColors.textMuted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(t('ภาษา', 'Language'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  _LanguageChip(
                    label: 'ภาษาไทย',
                    selected: !LocaleController.instance.isEnglish,
                    onTap: () => _setLocale(AppLocale.th),
                  ),
                  const SizedBox(width: 8),
                  _LanguageChip(
                    label: 'English',
                    selected: LocaleController.instance.isEnglish,
                    onTap: () => _setLocale(AppLocale.en),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t('บางหน้าที่ยังไม่ได้แปลจะแสดงเป็นภาษาไทยไปก่อน',
                    'Screens that have not been translated yet stay in Thai'),
                style: const TextStyle(
                    fontSize: 11.5, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 8),
              const Divider(color: OnboardingColors.border),
              _MenuRow(
                label: t('ตรวจสอบระบบเตือน', 'Check the reminder system'),
                trailing: Icons.chevron_right,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationCheckScreen(),
                  ),
                ),
              ),
              if (_canManagePrivacy)
                _MenuRow(
                  label: t('ตั้งค่าความเป็นส่วนตัว', 'Privacy settings'),
                  trailing: Icons.chevron_right,
                  onTap: _openPrivacySettings,
                ),
              const SizedBox(height: 16),
              const Divider(color: OnboardingColors.border),
              const SizedBox(height: 12),
              Text(t('นโยบาย', 'Policies'),
                  style: const TextStyle(color: OnboardingColors.textMuted)),
              const SizedBox(height: 8),
              _MenuRow(
                label: t('นโยบายความเป็นส่วนตัว', 'Privacy policy'),
                trailing: Icons.chevron_right,
                onTap: () => _openDocument(privacyPolicy),
              ),
              _MenuRow(
                label: t('ข้อตกลงและเงื่อนไข', 'Terms and conditions'),
                trailing: Icons.chevron_right,
                onTap: () => _openDocument(termsOfUse),
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
          color: selected ? OnboardingColors.teal.withValues(alpha: 0.12) : null,
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
