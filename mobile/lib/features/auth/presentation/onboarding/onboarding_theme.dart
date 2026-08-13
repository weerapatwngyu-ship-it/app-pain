import 'package:flutter/material.dart';

/// Visual language for the phone/OTP/PIN onboarding flow — kept separate
/// from [AppTheme] because it deliberately mirrors a specific reference
/// design (teal accent, white cards, rounded square icon buttons) rather
/// than the app's general theme.
class OnboardingColors {
  OnboardingColors._();

  static const teal = Color(0xFF5FBDB0);
  static const tealDisabled = Color(0xFFBFE1DB);
  static const border = Color(0xFFE1E1E1);
  static const text = Color(0xFF1B1B1B);
  static const textMuted = Color(0xFF6B6B6B);
}

/// Rounded-square icon button used for the close/back control at the top
/// of every onboarding screen.
class OnboardingIconButton extends StatelessWidget {
  const OnboardingIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.onDark = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Set when the button sits on the teal banner. The default grey outline and
  /// near-black glyph all but disappear there.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.18) : null,
          border: Border.all(
            color: onDark ? Colors.white54 : OnboardingColors.border,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: onDark ? Colors.white : OnboardingColors.text),
      ),
    );
  }
}

/// Full-width teal button, greyed out and non-interactive when disabled.
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: OnboardingColors.teal,
          disabledBackgroundColor: OnboardingColors.tealDisabled,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Title header shared by every onboarding screen: icon button top-left,
/// bold title beside/below it.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.icon,
    required this.onIconTap,
    required this.title,
  });

  final IconData icon;
  final VoidCallback onIconTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OnboardingIconButton(icon: icon, onTap: onIconTap),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: OnboardingColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
