import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A horizontal row that drifts along on its own and still takes a swipe.
///
/// Built for rows with more items than fit the screen, where the ones past the
/// edge are otherwise never seen — nothing on screen suggests the row
/// continues. Movement is the hint.
///
/// The list is looped rather than bounced: the builder is handed an index
/// modulo the real count and the scroll starts far from either end, so the
/// drift never reaches a boundary and never has to snap back to the start in
/// front of the user.
class AutoScrollStrip extends StatefulWidget {
  const AutoScrollStrip({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.separatorWidth = 12,
    this.pixelsPerSecond = 22,
    this.resumeAfter = const Duration(seconds: 2),
  });

  /// Number of real items. The list repeats them.
  final int itemCount;

  /// Called with an index in `0..itemCount-1`.
  final Widget Function(BuildContext context, int index) itemBuilder;

  final double height;
  final double separatorWidth;

  /// Drift speed. Slow on purpose: this is a hint that the row continues, not
  /// a carousel demanding to be watched.
  final double pixelsPerSecond;

  /// How long to wait after the user lets go before drifting again. It keeps
  /// the row from tugging against someone still reading it, and covers the
  /// fling that follows a swipe — the drift stays out of the way until that
  /// has settled rather than trying to detect it.
  final Duration resumeAfter;

  @override
  State<AutoScrollStrip> createState() => _AutoScrollStripState();
}

// TickerProviderStateMixin, not the Single variant: the ticker is thrown away
// and rebuilt when the item count changes, and the single-ticker mixin asserts
// on the second createTicker for the life of the State.
class _AutoScrollStripState extends State<AutoScrollStrip>
    with TickerProviderStateMixin {
  /// Enough repeats that neither end is reachable by drifting or by a person
  /// swiping for as long as they care to.
  static const _loops = 1000;

  final _controller = ScrollController();

  /// Whether the real items overflow the row.
  ///
  /// Decided after the first layout rather than guessed from a count: two wide
  /// tiles can overflow where six narrow ones do not. Until it is known the
  /// list holds the real items only — repeating them first would make a row
  /// that fits on screen scrollable, and it would then drift through copies of
  /// the same two entries.
  bool _looping = false;

  /// A ticker rather than a periodic timer: the framework mutes tickers when
  /// the route is not showing, so pushing another screen stops the drift
  /// without this widget having to notice.
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  Timer? _resumeTimer;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(AutoScrollStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The count can change under us — a directory that arrives after the first
    // frame, or a row that gains an entry. Whether the items overflow has to
    // be decided again, and the old ticker was started against the old length.
    if (oldWidget.itemCount != widget.itemCount) {
      _ticker?.dispose();
      _ticker = null;
      _looping = false;
      _lastTick = Duration.zero;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (!mounted || _looping) return;
    // Someone who has asked the system to reduce motion should not be handed a
    // row that moves by itself.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    if (widget.itemCount < 2) return;
    if (!_controller.hasClients) return;

    // Everything already visible: nothing is hidden past the edge, so there is
    // nothing for movement to reveal.
    if (_controller.position.maxScrollExtent <= 0) return;

    setState(() => _looping = true);

    // Once repeated, start partway in so a backwards swipe has somewhere to go.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final middle = _controller.position.maxScrollExtent / 2;
      if (middle.isFinite && middle > 0) _controller.jumpTo(middle);
      _ticker?.dispose();
      _ticker = createTicker(_onTick)..start();
    });
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;

    if (_paused || !_controller.hasClients) return;
    final position = _controller.position;

    // A row whose items all fit has nothing to reveal, so leave it still.
    if (position.maxScrollExtent <= 0) return;

    final step = widget.pixelsPerSecond * delta.inMilliseconds / 1000;
    if (step <= 0) return;

    final next = position.pixels + step;
    // Only reachable if the repeated list somehow ends; wrapping keeps it off
    // the edge rather than stuck against it.
    _controller.jumpTo(next >= position.maxScrollExtent ? 0 : next);
  }

  void _pause() {
    _resumeTimer?.cancel();
    _paused = true;
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.resumeAfter, () {
      if (mounted) _paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return SizedBox(height: widget.height);

    return SizedBox(
      height: widget.height,
      // Pointer events rather than a scroll listener: the drift is itself a
      // scroll, so listening for scrolls would pause on its own movement.
      child: Listener(
        onPointerDown: (_) => _pause(),
        onPointerUp: (_) => _scheduleResume(),
        onPointerCancel: (_) => _scheduleResume(),
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemCount: _looping ? widget.itemCount * _loops : widget.itemCount,
          separatorBuilder: (_, __) => SizedBox(width: widget.separatorWidth),
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, index % widget.itemCount),
          // A row that fits should not offer to scroll at all.
          physics: _looping
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
        ),
      ),
    );
  }
}
