import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'message_jump.dart';
import 'message_list_anchor.dart';

/// Wraps the message list's sliver (a [SliverList] of [rows]) and, while
/// [jump] has a target among them, corrects the scroll offset during layout
/// so that row sits centred — through [SliverGeometry.scrollOffsetCorrection],
/// which the viewport applies and lays out again within the same frame.
/// While still looking for the row it paints nothing, so the rows passed on
/// the way never flash by. A place held while rows are added below it is put
/// back the same way.
class MessageJumpSliver extends SingleChildRenderObjectWidget {
  const MessageJumpSliver({
    super.key,
    required this.jump,
    required this.rows,
    required Widget sliver,
  }) : super(child: sliver);

  final MessageJump jump;

  /// The list's rows, by index as the sliver builds them.
  final List<Object> rows;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageJumpSliver(jump, rows);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderMessageJumpSliver)
      ..jump = jump
      ..rows = rows;
  }
}

/// Corrections asked for in one frame; the viewport allows ten layout passes
/// for a single sliver, and the list itself may need some.
const int _kMaxCorrectionsPerFrame = 4;

class _RenderMessageJumpSliver extends RenderProxySliver {
  _RenderMessageJumpSliver(this._jump, this._rows);

  MessageJump _jump;
  set jump(MessageJump value) {
    if (identical(value, _jump)) return;
    if (attached) {
      _jump.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }
    _jump = value;
    markNeedsLayout();
  }

  List<Object> _rows;
  set rows(List<Object> value) {
    if (identical(value, _rows)) return;
    _rows = value;
    if (_jump.target != null || _jump.place != null) markNeedsLayout();
  }

  /// Still looking for the target row: painted as nothing.
  bool _hidden = false;
  int _corrections = 0;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _jump.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _jump.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    final hidden = _hidden;
    _hidden = false;
    // In a layout callback: reading the rows' sizes (the list's children,
    // not this sliver's) is allowed there.
    invokeLayoutCallback<SliverConstraints>((_) => _correct());
    if (hidden != _hidden) markNeedsPaint();
  }

  void _correct() {
    final list = child;
    if (list is! RenderSliverMultiBoxAdaptor) return;
    // The list is fixing its own offsets first.
    if (geometry!.scrollOffsetCorrection != null) return;
    if (_jump.target != null) return _centre(list, _jump.target!);
    if (_jump.place != null) _keepPlace(list, _jump.place!);
  }

  void _centre(RenderSliverMultiBoxAdaptor list, int target) {
    final index = MessageJump.indexIn(_rows, target);
    if (index < 0 || !_jump.holds(_frameTime)) return;
    _hidden = _jump.seeking;
    final row = _rowAt(list, index);
    if (row == null) return;
    final c = constraints;
    final delta = _deltaTo(
      row.start +
          row.height / 2 +
          c.precedingScrollExtent -
          c.viewportMainAxisExtent / 2,
    );
    if (delta.abs() >= 0.5) return _scrollBy(delta);
    if (row.laidOut) {
      _jump.arrive();
      _hidden = false;
    }
  }

  /// Puts the row being read back where it was, after rows were added below
  /// it — before the frame is painted, so it is never seen pushed away.
  void _keepPlace(RenderSliverMultiBoxAdaptor list, MessageListAnchor place) {
    final index = place.indexIn(_rows);
    final row = index < 0 ? null : _rowAt(list, index);
    if (row == null) return _jump.settlePlace();
    final delta = _deltaTo(place.pixelsFor(row.start + row.height));
    // There (or as near as the list's extent allows).
    if (delta.abs() < 0.5) return _jump.settlePlace();
    // Not painted where the reader would lose it, should the passes of
    // this frame run out.
    _hidden = true;
    _scrollBy(delta);
  }

  /// Asks the viewport to scroll by [delta] and lay out again. Out of
  /// passes for this frame: carried on in the next one, still hidden if not
  /// there yet.
  void _scrollBy(double delta) {
    if (_corrections >= _kMaxCorrectionsPerFrame) return;
    if (_corrections++ == 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _corrections = 0;
        if (!attached) return;
        if (_jump.target != null || _jump.place != null) markNeedsLayout();
      });
    }
    geometry = SliverGeometry(scrollOffsetCorrection: delta);
  }

  static Duration? get _frameTime {
    final binding = SchedulerBinding.instance;
    return binding.schedulerPhase == SchedulerPhase.idle
        ? null
        : binding.currentFrameTimeStamp;
  }

  /// Where row [index] starts (in the list's offsets) and how tall it is;
  /// estimated from the average row when it is not laid out. Null when
  /// nothing is laid out.
  ({double start, double height, bool laidOut})? _rowAt(
    RenderSliverMultiBoxAdaptor list,
    int index,
  ) {
    final first = list.firstChild;
    final last = list.lastChild;
    if (first == null || last == null) return null;
    for (RenderBox? box = first; box != null; box = list.childAfter(box)) {
      if (list.indexOf(box) != index) continue;
      final offset = list.childScrollOffset(box);
      if (offset == null) break;
      return (start: offset, height: box.size.height, laidOut: true);
    }
    final start = list.childScrollOffset(first);
    final lastOffset = list.childScrollOffset(last);
    if (start == null || lastOffset == null) return null;
    final firstIndex = list.indexOf(first);
    final lastIndex = list.indexOf(last);
    final end = lastOffset + last.size.height;
    final average = (end - start) / (lastIndex - firstIndex + 1);
    // Reversed or not, offsets grow with the index.
    return (
      start: index > lastIndex
          ? end + average * (index - lastIndex - 1)
          : start - average * (firstIndex - index),
      height: average,
      laidOut: false,
    );
  }

  /// How far to scroll for the scroll position to become [pixels], within
  /// the list's extent.
  double _deltaTo(double pixels) {
    final c = constraints;
    // Where this sliver starts in the viewport, when it starts inside it.
    final lead = c.viewportMainAxisExtent - c.remainingPaintExtent;
    final now = c.precedingScrollExtent + c.scrollOffset - lead;
    final maxPixels =
        c.precedingScrollExtent +
        geometry!.scrollExtent -
        c.viewportMainAxisExtent;
    final up = math.max(0.0, maxPixels - now);
    final down = math.min(-now, up);
    return (pixels - now).clamp(down, up).toDouble();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) =>
      !_hidden &&
      super.hitTestChildren(
        result,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
}
