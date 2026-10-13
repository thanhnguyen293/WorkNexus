import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three dots rising one after another, the familiar "someone is typing"
/// cue. They hold still when the platform asks for reduced motion.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color, required this.size});

  final Color color;

  /// Diameter of one dot; gaps and the rise scale with it.
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  // One wave across the three dots. A loop rather than a transition, so it
  // is not one of the AppMotion durations.
  static const _period = Duration(milliseconds: 1200);

  /// The share of the period each dot spends rising and falling, and how
  /// far behind its left neighbour it starts.
  static const _riseShare = 0.4;
  static const _stagger = 0.15;

  late final _wave = AnimationController(vsync: this, duration: _period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.value = 0;
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  /// 0 at rest, 1 at the top of the rise, for dot [i] at wave position [t].
  double _lift(int i, double t) {
    final phase = (t - i * _stagger) % 1.0;
    return phase < _riseShare ? math.sin(math.pi * phase / _riseShare) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final dot = DecoratedBox(
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      child: SizedBox.square(dimension: size),
    );
    // Room above the dots for the rise, so it never overlaps the line above.
    return Padding(
      padding: EdgeInsets.only(top: size * 0.6),
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : size * 0.5),
                child: Transform.translate(
                  offset: Offset(0, -size * 0.6 * _lift(i, _wave.value)),
                  child: Opacity(
                    opacity: 0.4 + 0.6 * _lift(i, _wave.value),
                    child: dot,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
