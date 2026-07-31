import 'package:flutter/material.dart';

import 'onboarding_theme.dart';

/// A row of dots representing PIN digits — filled teal once typed, matching
/// the reference design's PIN entry boxes.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filledCount, this.active = true});

  final int length;
  final int filledCount;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: active ? OnboardingColors.teal : OnboardingColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(length, (index) {
          final filled = index < filledCount;
          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? OnboardingColors.teal : Colors.transparent,
              border: filled ? null : Border.all(color: OnboardingColors.border),
            ),
          );
        }),
      ),
    );
  }
}

/// Custom numeric keypad (1-9, 0, backspace) used for PIN entry — the
/// reference design uses its own keypad instead of the system keyboard.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) => _KeypadButton(label: digit, onTap: () => onDigit(digit))).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 64, height: 64),
              _KeypadButton(label: '0', onTap: () => onDigit('0')),
              _KeypadButton(icon: Icons.backspace_outlined, onTap: onBackspace),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: icon != null
              ? Icon(icon, color: OnboardingColors.text)
              : Text(label!, style: const TextStyle(fontSize: 24, color: OnboardingColors.text)),
        ),
      ),
    );
  }
}
