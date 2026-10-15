import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/connections/presentation/connect_account_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Dashed outline "+ Connect" button in the app navigation rail (design §8, specs S3.1).
/// Opens [ConnectAccountDialog].
class RailConnectButton extends StatefulWidget {
  const RailConnectButton({super.key});

  @override
  State<RailConnectButton> createState() => _RailConnectButtonState();
}

class _RailConnectButtonState extends State<RailConnectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);

    final borderColor = _hovered ? c.accent : c.borderStrong;

    return Semantics(
      button: true,
      child: Tooltip(
        message: l.connectATool,
        preferBelow: false,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: () => ConnectAccountDialog.show(context),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: s.xxs),
              child: CustomPaint(
                painter: _DashedRRectPainter(
                  color: borderColor,
                  radius: r.md,
                  strokeWidth: 1.2,
                ),
                child: Container(
                  width: context.sizes.railWidth - s.xl,
                  padding: EdgeInsets.symmetric(
                    vertical: s.xs,
                    horizontal: s.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: _hovered ? c.selectionFill : Colors.transparent,
                    borderRadius: BorderRadius.circular(r.md),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: context.sizes.railButton,
                        height: context.sizes.railButton,
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.plus300,
                          size: context.sizes.iconMd,
                          color: _hovered ? c.accent : c.textSecondary,
                        ),
                      ),
                      SizedBox(height: s.xxs),
                      Text(
                        'Connect',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.typography.captionSm.copyWith(
                          color: _hovered ? c.accent : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.0,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dashLength = 4.0;
  static const _gapLength = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        final extract = metric.extractPath(
          distance,
          next > metric.length ? metric.length : next,
        );
        canvas.drawPath(extract, paint);
        distance += _dashLength + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth;
}
