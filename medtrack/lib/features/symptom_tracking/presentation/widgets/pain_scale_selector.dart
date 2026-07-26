import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// 0–10 pain scale picker. Color ramps from the primary teal (no pain)
/// through warm amber to critical red as the score rises, so the
/// severity reads at a glance without needing the number.
class PainScaleSelector extends StatelessWidget {
  const PainScaleSelector({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  Color _colorFor(int score) {
    if (score <= 3) return AppColors.primary;
    if (score <= 6) return AppColors.warm;
    return AppColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ระดับความเจ็บปวด (0 = ไม่เจ็บ, 10 = เจ็บมากที่สุด)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(11, (score) {
            final selected = score == value;
            final color = _colorFor(score);
            return GestureDetector(
              onTap: () => onChanged(score),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? color : AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
