import 'package:flutter/material.dart';

/// A small red dot marking something unopened.
///
/// A dot rather than a count: the number of unread threads is not information
/// a patient acts on differently at two than at one, and a badge that says "12"
/// on a medical app reads as a backlog to feel guilty about. The dot answers
/// the only question being asked — is there something new.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, this.size = 10, this.borderColor});

  final double size;

  /// Ring drawn around the dot so it stays visible against whatever it sits
  /// on. Null for a dot on a plain background, where a ring would just look
  /// like a smudge.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
    );
  }
}

/// Puts an [UnreadDot] on the top-right corner of [child].
///
/// The dot is allowed to overflow the child's box, which is what makes it read
/// as a badge on the thing rather than as part of its layout — so the icon
/// underneath does not shift when the dot appears and disappears.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.child,
    required this.show,
    this.dotSize = 10,
    this.borderColor,
  });

  final Widget child;
  final bool show;
  final double dotSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          child: UnreadDot(size: dotSize, borderColor: borderColor),
        ),
      ],
    );
  }
}
