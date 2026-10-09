import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// An image in the rich-text editor at its chosen [width] (null = as wide as
/// it fits). Hovering shows size presets — the width is stored on the image,
/// so it is written back to ZenTao as `<img width>`.
class EditorImageFrame extends StatefulWidget {
  const EditorImageFrame({
    super.key,
    required this.width,
    required this.onResize,
    required this.child,
  });

  /// Widths offered on hover, in logical pixels.
  static const presets = [240.0, 480.0, 720.0];

  final double? width;

  /// Sets the width; null when the editor is read-only (no presets shown).
  final ValueChanged<double?>? onResize;

  /// The image, already sized to [width].
  final Widget child;

  @override
  State<EditorImageFrame> createState() => _EditorImageFrameState();
}

class _EditorImageFrameState extends State<EditorImageFrame> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final resize = widget.onResize;
    final image = Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(
            color: _hover && resize != null ? c.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
    if (resize == null) return image;
    final l = AppL10n.of(context);
    final labels = [l.imageSizeSmall, l.imageSizeMedium, l.imageSizeLarge];
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        children: [
          image,
          if (_hover)
            Positioned(
              top: context.spacing.sm,
              left: context.spacing.sm,
              child: _Presets(
                options: [
                  for (final (i, w) in EditorImageFrame.presets.indexed)
                    (label: labels[i], width: w),
                  (label: l.imageSizeOriginal, width: null),
                ],
                selected: widget.width,
                onPick: resize,
              ),
            ),
        ],
      ),
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets({
    required this.options,
    required this.selected,
    required this.onPick,
  });

  final List<({String label, double? width})> options;
  final double? selected;
  final ValueChanged<double?> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Material(
      color: c.card,
      elevation: 2,
      shadowColor: c.scrim.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Padding(
        padding: EdgeInsets.all(s.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              InkWell(
                onTap: () => onPick(o.width),
                borderRadius: BorderRadius.circular(context.radii.sm),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.md,
                    vertical: s.xs,
                  ),
                  decoration: BoxDecoration(
                    color: o.width == selected
                        ? c.mixT(c.accent, 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(context.radii.sm),
                  ),
                  child: Text(
                    o.label,
                    style: context.typography.bodySmStrong.copyWith(
                      color: o.width == selected ? c.accent : c.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
