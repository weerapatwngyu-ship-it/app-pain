import 'package:flutter/material.dart';

import '../../../core/i18n/app_locale.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/legal_documents.dart';

/// Renders either the privacy policy or the terms.
///
/// One screen for both because they are the same shape — a lead-in and then
/// headed sections — and a second copy of this layout would be one more place
/// for the two to drift out of step visually.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(document.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            document.intro,
            style: const TextStyle(
              fontSize: 14,
              height: 1.65,
              color: OnboardingColors.text,
            ),
          ),
          const SizedBox(height: 8),
          for (final section in document.sections) ...[
            const SizedBox(height: 22),
            Text(
              section.heading,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OnboardingColors.text,
              ),
            ),
            const SizedBox(height: 8),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 10),
                      child: _Dot(),
                    ),
                    Expanded(
                      child: Text(
                        paragraph,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.65,
                          color: OnboardingColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 28),
          // Said out loud rather than left for someone to discover: the text
          // above describes this build honestly, but describing something
          // accurately is not the same as it having been checked by a lawyer.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              t(
                'ข้อความนี้เขียนตามการทำงานจริงของแอปในเวอร์ชันนี้ '
                    'และยังไม่ผ่านการตรวจโดยนักกฎหมาย '
                    'หากมีข้อสงสัย ติดต่อผู้ดูแลระบบ',
                'This text describes how this version of the app actually '
                    'works. It has not been reviewed by a lawyer. If anything '
                    'is unclear, contact an administrator.',
              ),
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: OnboardingColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: OnboardingColors.teal,
        shape: BoxShape.circle,
      ),
    );
  }
}
