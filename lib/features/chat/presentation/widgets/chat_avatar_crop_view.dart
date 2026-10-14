import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/value_objects/chat_avatar_crop.dart';
import 'chat_avatar_crop_mask.dart';

/// The frame's corners, as signs: `x`/`y` are -1 (left/top) or 1.
const _kCorners = [
  Alignment.topLeft,
  Alignment.topRight,
  Alignment.bottomLeft,
  Alignment.bottomRight,
];

/// The whole picture, fitted in [maxSize], under a square frame: drag the
/// frame to move it, a corner to resize it. The round mask shows what the
/// avatar keeps; [onChanged] reports that square in the picture's own pixels.
class ChatAvatarCropView extends StatefulWidget {
  const ChatAvatarCropView({
    super.key,
    required this.image,
    required this.imageSize,
    required this.maxSize,
    required this.onChanged,
  });

  final ImageProvider image;
  final Size imageSize;
  final Size maxSize;
  final ValueChanged<ChatAvatarCrop> onChanged;

  @override
  State<ChatAvatarCropView> createState() => _ChatAvatarCropViewState();
}

class _ChatAvatarCropViewState extends State<ChatAvatarCropView> {
  /// Picture px → view px.
  late double _scale;

  /// The frame, in view px over the shown picture.
  Rect _frame = Rect.zero;

  /// Where the dragged corner would be, unclamped: it keeps following the
  /// pointer while the frame is stopped at an edge.
  Offset _pointer = Offset.zero;
  Offset _anchor = Offset.zero;
  double _startSide = 0;

  bool _placed = false;

  double get _grip => context.sizes.controlSm;

  Size get _shown => widget.imageSize * _scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_placed) return;
    _placed = true;
    // Corner grips straddle the picture's edge, so leave them room.
    final room = Size(
      widget.maxSize.width - _grip,
      widget.maxSize.height - _grip,
    );
    final size = widget.imageSize;
    _scale = math.min(room.width / size.width, room.height / size.height);
    // Starts on the biggest centred square, as cut without a crop.
    final side = math.min(_shown.width, _shown.height);
    _frame = Rect.fromCenter(
      center: _shown.center(Offset.zero),
      width: side,
      height: side,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted) return;
    widget.onChanged(
      ChatAvatarCrop(
        left: _frame.left / _scale,
        top: _frame.top / _scale,
        side: _frame.width / _scale,
      ),
    );
  }

  void _move(Offset delta) {
    final moved = _frame.shift(delta);
    setState(
      () => _frame = Rect.fromLTWH(
        moved.left.clamp(0, _shown.width - moved.width),
        moved.top.clamp(0, _shown.height - moved.height),
        moved.width,
        moved.height,
      ),
    );
    _report();
  }

  void _startResize(Alignment corner) {
    _pointer = corner.withinRect(_frame);
    _anchor = Alignment(-corner.x, -corner.y).withinRect(_frame);
    _startSide = _frame.width;
  }

  /// Resizes from [corner], the opposite corner staying put.
  void _resize(Alignment corner, Offset delta) {
    _pointer += delta;
    final roomX = corner.x > 0 ? _shown.width - _anchor.dx : _anchor.dx;
    final roomY = corner.y > 0 ? _shown.height - _anchor.dy : _anchor.dy;
    final room = math.min(roomX, roomY);
    // The axis the pointer moved more along sets the side, so the corner
    // follows it whichever way it is dragged.
    final grewX = (_pointer.dx - _anchor.dx) * corner.x - _startSide;
    final grewY = (_pointer.dy - _anchor.dy) * corner.y - _startSide;
    final wanted = _startSide + (grewX.abs() > grewY.abs() ? grewX : grewY);
    final side = wanted.clamp(math.min(_grip * 2, room), room).toDouble();
    setState(
      () => _frame = Rect.fromLTWH(
        corner.x > 0 ? _anchor.dx : _anchor.dx - side,
        corner.y > 0 ? _anchor.dy : _anchor.dy - side,
        side,
        side,
      ),
    );
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Everything is laid out [margin] in, so the grips stay hittable.
    final margin = Offset(_grip / 2, _grip / 2);
    final frame = _frame.shift(margin);
    return SizedBox.fromSize(
      size: _shown + margin * 2,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: margin & _shown,
            child: Image(image: widget.image, fit: BoxFit.fill),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ChatAvatarCropMask(
                  picture: margin & _shown,
                  frame: frame,
                  scrim: c.scrim,
                  ink: c.onScrim,
                  ringWidth: context.borders.thick,
                  dotRadius: context.spacing.sm,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: frame,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onPanUpdate: (d) => _move(d.delta),
              ),
            ),
          ),
          for (final corner in _kCorners)
            Positioned.fromRect(
              rect: Rect.fromCenter(
                center: corner.withinRect(frame),
                width: _grip,
                height: _grip,
              ),
              child: MouseRegion(
                cursor: corner.x == corner.y
                    ? SystemMouseCursors.resizeUpLeftDownRight
                    : SystemMouseCursors.resizeUpRightDownLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (_) => _startResize(corner),
                  onPanUpdate: (d) => _resize(corner, d.delta),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
