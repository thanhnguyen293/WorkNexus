import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// An image in the rich-text editor at its chosen [width] (null = as wide as
/// it fits). Hovering outlines it and shows a handle on its bottom-right
/// corner; dragging the handle resizes it live (keeping its proportions) and
/// stores the width on release, so it is written back to ZenTao as
/// `<img width>`. Double-clicking the handle fits it to the editor again.
class EditorImageFrame extends StatefulWidget {
  const EditorImageFrame({
    super.key,
    required this.width,
    required this.onResize,
    required this.builder,
  });

  final double? width;

  /// Stores the width; null when the editor is read-only (no handle).
  final ValueChanged<double?>? onResize;

  /// Builds the image at a width (null = fit), with no padding of its own so
  /// the outline hugs it.
  final Widget Function(double? width) builder;

  @override
  State<EditorImageFrame> createState() => _EditorImageFrameState();
}

class _EditorImageFrameState extends State<EditorImageFrame> {
  /// Narrower than this an image is no longer readable.
  static const _minWidth = 64.0;

  final _imageKey = GlobalKey();
  bool _hover = false;

  /// The width while a drag is under way; null otherwise.
  double? _dragWidth;

  /// Where the drag began and the image's width then; the width follows the
  /// pointer from there, so the drag slop does not shift it.
  ({double x, double width})? _dragFrom;

  void _start(DragStartDetails d) {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? widget.width ?? _minWidth;
    _dragFrom = (x: d.globalPosition.dx, width: width);
    setState(() => _dragWidth = width);
  }

  void _update(DragUpdateDetails d, double maxWidth) {
    final from = _dragFrom;
    if (from == null) return;
    final width = from.width + d.globalPosition.dx - from.x;
    setState(() => _dragWidth = width.clamp(_minWidth, maxWidth));
  }

  void _end() {
    final w = _dragWidth;
    _dragFrom = null;
    setState(() => _dragWidth = null);
    if (w != null) widget.onResize?.call(w.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final resize = widget.onResize;
    if (resize == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: widget.builder(widget.width),
        ),
      );
    }
    final c = context.colors;
    final active = _hover || _dragWidth != null;
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: EdgeInsets.symmetric(vertical: s.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Stack(
              children: [
                DecoratedBox(
                  key: _imageKey,
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    // Matches the image's own rounded clip.
                    borderRadius: BorderRadius.circular(context.radii.md),
                    border: Border.all(
                      color: active ? c.accent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: widget.builder(_dragWidth ?? widget.width),
                ),
                if (active)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _CornerHandle(
                      onStart: _start,
                      onUpdate: (d) => _update(d, box.maxWidth),
                      onEnd: _end,
                      onReset: () => resize(null),
                    ),
                  ),
                if (_dragWidth case final w?)
                  Positioned(
                    top: s.sm,
                    left: s.sm,
                    child: _SizeLabel('${w.round()} px'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small square on the image's bottom-right corner. Its hit area reaches
/// further into the image than it shows, so it is easy to grab.
class _CornerHandle extends StatelessWidget {
  const _CornerHandle({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onReset,
  });

  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Tooltip(
      message: AppL10n.of(context).imageResizeHint,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: onStart,
          onPanUpdate: onUpdate,
          onPanEnd: (_) => onEnd(),
          onPanCancel: onEnd,
          onDoubleTap: onReset,
          child: Padding(
            padding: EdgeInsets.only(left: s.md, top: s.md),
            child: Container(
              width: s.lg,
              height: s.lg,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(context.radii.xs),
                  bottomRight: Radius.circular(context.radii.md),
                ),
                border: Border.all(color: c.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeLabel extends StatelessWidget {
  const _SizeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xxs),
      decoration: BoxDecoration(
        color: c.scrim.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
      child: Text(
        text,
        style: context.typography.monoSm.copyWith(color: c.onScrim),
      ),
    );
  }
}
