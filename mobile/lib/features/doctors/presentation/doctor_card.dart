import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/doctor.dart';

/// A doctor as they appear in the directory.
///
/// Every row is conditional. A listing with only a name and a specialty shows
/// exactly those, and the card closes up around what is missing — nothing here
/// substitutes a dash, a zero, or an invented figure for a fact nobody
/// recorded. These are real practitioners; an empty field means unknown, and
/// unknown should look like absence rather than data.
class DoctorCard extends StatelessWidget {
  const DoctorCard({
    super.key,
    required this.doctor,
    required this.onTap,
    this.consultCount,
  });

  final Doctor doctor;
  final VoidCallback onTap;

  /// Patients who have consulted this doctor, counted in the database. Null
  /// while it is still loading, or if the count could not be read.
  final int? consultCount;

  @override
  Widget build(BuildContext context) {
    final photoUrl = doctor.photoUrl;
    final fee = doctor.feeText;
    final duration = doctor.durationText;
    final badge = doctor.languageBadge;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OnboardingColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _PhotoFallback(),
                            )
                          : const _PhotoFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                doctor.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (badge.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _Pill(text: badge),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _SpecialtyChip(label: doctor.specialty),
                        if (doctor.credential != null) ...[
                          const SizedBox(height: 8),
                          _IconLine(
                            icon: Icons.workspace_premium_outlined,
                            text: doctor.credential!,
                          ),
                        ],
                        if (doctor.workplace != null) ...[
                          const SizedBox(height: 4),
                          _IconLine(
                            icon: Icons.place_outlined,
                            text: doctor.workplace!,
                          ),
                        ],
                        if (consultCount != null && consultCount! > 0) ...[
                          const SizedBox(height: 4),
                          _IconLine(
                            icon: Icons.forum_outlined,
                            text: '$consultCount คนเคยปรึกษา',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // The strip only appears when there is something to put in it,
              // so a listing without a fee does not grow an empty band.
              if (fee != null || duration != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3FAF8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (fee != null) ...[
                        const Icon(Icons.payments_outlined,
                            size: 17, color: OnboardingColors.teal),
                        const SizedBox(width: 6),
                        Text(
                          fee,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: OnboardingColors.teal,
                          ),
                        ),
                      ],
                      if (fee != null && duration != null)
                        Container(
                          width: 1,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: OnboardingColors.border,
                        ),
                      if (duration != null) ...[
                        const Icon(Icons.schedule,
                            size: 17, color: OnboardingColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: OnboardingColors.textMuted,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          size: 20, color: OnboardingColors.textMuted),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OnboardingColors.teal,
      child: const Icon(Icons.medical_services_outlined,
          color: Colors.white, size: 30),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OnboardingColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: OnboardingColors.textMuted,
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OnboardingColors.teal,
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: OnboardingColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: OnboardingColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
