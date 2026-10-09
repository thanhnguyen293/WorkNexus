import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

// The picker's gradients are colour math (no saturation is white, no
// value is black), not theme colours — so they're derived, not tokens.
final Color _kWhite = const HSVColor.fromAHSV(1, 0, 0, 1).toColor();
final Color _kBlack = const HSVColor.fromAHSV(1, 0, 0, 0).toColor();

/// Saturation (left → right) by brightness (top → bottom) for one hue of
/// [color]; click or drag to pick.
class HsvSaturationValueArea extends StatelessWidget {
  const HsvSaturationValueArea({
    required this.color,
    required this.onChanged,
    super.key,
  });

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  void _pick(Offset at, Size size) {
    final x = (at.dx / size.width).clamp(0.0, 1.0);
    final y = (at.dy / size.height).clamp(0.0, 1.0);
    onChanged(color.withSaturation(x).withValue(1 - y));
  }

  @override
  Widget build(BuildContext context) {
    final hue = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor();
    final radius = BorderRadius.circular(context.radii.md);
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            // A drag surface, not a button: no tap target to hover-tint.
            child: GestureDetector(
              onPanDown: (d) => _pick(d.localPosition, size),
              onPanUpdate: (d) => _pick(d.localPosition, size),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(colors: [_kWhite, hue]),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, _kBlack],
                        ),
                      ),
                    ),
                  ),
                  _Knob(
                    center: Offset(
                      color.saturation * size.width,
                      (1 - color.value) * size.height,
                    ),
                    fill: color.toColor(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The hue as a rainbow bar; click or drag to pick.
class HsvHueBar extends StatelessWidget {
  const HsvHueBar({required this.color, required this.onChanged, super.key});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  void _pick(Offset at, double width) {
    final x = (at.dx / width).clamp(0.0, 1.0);
    onChanged(color.withHue(x * 360));
  }

  @override
  Widget build(BuildContext context) {
    final height = context.spacing.xl3;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              onPanDown: (d) => _pick(d.localPosition, width),
              onPanUpdate: (d) => _pick(d.localPosition, width),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height / 2),
                        gradient: LinearGradient(
                          colors: [
                            for (var h = 0; h <= 360; h += 60)
                              HSVColor.fromAHSV(
                                1,
                                h.toDouble(),
                                1,
                                1,
                              ).toColor(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Knob(
                    center: Offset(color.hue / 360 * width, height / 2),
                    fill: HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The picked spot: a ringed dot of the colour under it.
class _Knob extends StatelessWidget {
  const _Knob({required this.center, required this.fill});

  final Offset center;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final size = context.spacing.xl3 + context.spacing.xxs;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.onScrim, width: 3),
            boxShadow: [
              BoxShadow(
                color: context.colors.mixT(context.colors.scrim, 0.35),
                blurRadius: context.spacing.xs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
