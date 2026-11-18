import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// Eases [child] in once, when it is first built: it fades in and, with
/// [grow], its height opens from nothing so what is around it moves aside
/// smoothly instead of jumping.
///
/// With [animate] false at first build (or the platform asking for less
/// motion) it shows [child] as it is and never animates; later changes to
/// [animate] are ignored, so a rebuilt row does not play it again. At rest
/// it adds no layer or clip.
class AppEntrance extends StatefulWidget {
  const AppEntrance({
    super.key,
    this.animate = true,
    this.grow = false,
    this.duration = AppMotion.base,
    required this.child,
  });

  final bool animate;
  final bool grow;
  final Duration duration;
  final Widget child;

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _curve;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decided once, here rather than in initState: it reads MediaQuery.
    if (_decided) return;
    _decided = true;
    if (!widget.animate || AppMotion.reduced(context)) return;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _curve = CurvedAnimation(parent: controller, curve: AppMotion.enter);
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    final faded = FadeTransition(opacity: _curve, child: widget.child);
    if (!widget.grow) return faded;
    return AnimatedBuilder(
      animation: _curve,
      // Not clipped: the fade hides what spills out while it opens, and a
      // clip would cut what the child draws past its edges on purpose.
      builder: (context, child) => Align(
        alignment: Alignment.topCenter,
        heightFactor: _curve.value,
        child: child,
      ),
      child: faded,
    );
  }
}
