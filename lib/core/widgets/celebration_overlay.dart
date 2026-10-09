import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../util/fireworks.dart';
import 'fireworks_painter.dart';

/// Counts celebrations; each [celebrate] sets off one firework show over the
/// whole app (see [CelebrationOverlay]).
class CelebrationController extends Notifier<int> {
  @override
  int build() => 0;

  void celebrate() => state++;
}

final celebrationProvider = NotifierProvider<CelebrationController, int>(
  CelebrationController.new,
);

/// Draws a firework show over [child] each time [celebrationProvider] ticks.
/// It never takes the pointer, and is skipped when the system asks for
/// reduced motion.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final _show = AnimationController(
    vsync: this,
    duration: fireworksDuration,
  );
  List<Spark> _sparks = const [];

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  void _start(int seed) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final size = MediaQuery.sizeOf(context);
    setState(() => _sparks = fireworkSparks(size, seed: seed));
    _show.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(celebrationProvider, (_, tick) => _start(tick));
    final c = context.colors;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _show,
              builder: (context, _) => _show.isAnimating
                  ? CustomPaint(
                      painter: FireworksPainter(
                        sparks: _sparks,
                        t: _show.value,
                        hot: c.onAccent,
                        palette: [
                          c.accent,
                          c.success,
                          c.warning,
                          c.error,
                          c.info,
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
