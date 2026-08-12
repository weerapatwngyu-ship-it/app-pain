import 'package:flutter/material.dart';

import '../../../../shared/theme/app_palette.dart';

/// Named colours the onboarding and patient screens were written against.
///
/// These now forward to [AppPalette] rather than holding their own values.
/// The names stay because forty screens reference them; what they point at
/// is decided in one place.
class OnboardingColors {
  OnboardingColors._();

  /// The accent. Named `teal` when the app was teal — kept as an alias so the
  /// screens still using that name keep working.
  static const teal = AppPalette.primary;
  static const tealDisabled = AppPalette.primaryDisabled;

  static const primary = AppPalette.primary;
  static const primaryDisabled = AppPalette.primaryDisabled;
  static const soft = AppPalette.soft;
  static const softBorder = AppPalette.softBorder;
  static const heading = AppPalette.heading;
  static const surface = AppPalette.surface;
  static const field = AppPalette.field;
  static const border = AppPalette.border;
  static const text = AppPalette.text;
  static const textMuted = AppPalette.textMuted;
}

/// Rounded-square icon button used for the close/back control at the top
/// of every onboarding screen.
class OnboardingIconButton extends StatelessWidget {
  const OnboardingIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: OnboardingColors.text),
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
