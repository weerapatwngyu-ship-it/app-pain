import 'package:flutter/material.dart';

/// Standard 0–10 pain scale input shared by symptom logging screens
/// (docs/architecture.md §3, §6 `SYMPTOM_LOG.pain_score`).
class PainScoreSlider extends StatelessWidget {
  const PainScoreSlider({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ระดับความเจ็บปวด: $value / 10', style: Theme.of(context).textTheme.titleMedium),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
