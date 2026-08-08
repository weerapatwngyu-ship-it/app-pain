import 'package:flutter/material.dart';

import '../../features/auth/presentation/onboarding/onboarding_theme.dart';

/// Circular avatar showing [avatarUrl] (an absolute URL) when set, else the
/// first letter of [name]. Pass [onTap] to make it editable — shows a small
/// camera badge, or a spinner overlay while [loading].
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
    this.onTap,
    this.loading = false,
  });

  final String name;
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: OnboardingColors.teal,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              name.trim().isEmpty ? '?' : name.trim()[0],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );

    if (onTap == null) return avatar;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Center(
                  child: SizedBox(
                    width: radius * 0.7,
                    height: radius * 0.7,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: OnboardingColors.teal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
