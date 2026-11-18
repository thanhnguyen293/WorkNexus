import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'message_jump.dart';

/// Wraps the message list's sliver (a [SliverList] of [rows]) and, while
/// [jump] has a target among them, corrects the scroll offset during layout
/// so that row sits centred — through [SliverGeometry.scrollOffsetCorrection],
/// which the viewport applies and lays out again within the same frame.
/// While still looking for the row it paints nothing, so the rows passed on
/// the way never flash by.
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
    if (_jump.target != null) markNeedsLayout();
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
    final target = _jump.target;
    if (target == null || list is! RenderSliverMultiBoxAdaptor) return;
    // The list is fixing its own offsets first.
    if (geometry!.scrollOffsetCorrection != null) return;
    final index = MessageJump.indexIn(_rows, target);
    if (index < 0 || !_jump.holds(_frameTime)) return;
    _hidden = _jump.seeking;
    final (:delta, :laidOut) =
        _offCentre(list, index) ?? (delta: 0.0, laidOut: false);
    if (delta.abs() < 0.5) {
      if (laidOut) {
        _jump.arrive();
        _hidden = false;
      }
      return;
    }
    // Out of passes for this frame: carried on in the next one, still
    // hidden if not there yet.
    if (_corrections >= _kMaxCorrectionsPerFrame) return;
    if (_corrections++ == 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _corrections = 0;
        if (attached && _jump.target != null) markNeedsLayout();
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

  /// How far to scroll for row [index] to sit centred, within the list's
  /// extent; estimated from the average row when it is not laid out. Null
  /// when nothing is laid out.
  ({double delta, bool laidOut})? _offCentre(
    RenderSliverMultiBoxAdaptor list,
    int index,
  ) {
    final first = list.firstChild;
    final last = list.lastChild;
    if (first == null || last == null) return null;
    double? centre;
    for (RenderBox? box = first; box != null; box = list.childAfter(box)) {
      if (list.indexOf(box) != index) continue;
      final offset = list.childScrollOffset(box);
      if (offset != null) centre = offset + box.size.height / 2;
      break;
    }
    final laidOut = centre != null;
    if (centre == null) {
      final start = list.childScrollOffset(first);
      final lastOffset = list.childScrollOffset(last);
      if (start == null || lastOffset == null) return null;
      final firstIndex = list.indexOf(first);
      final lastIndex = list.indexOf(last);
      final end = lastOffset + last.size.height;
      final average = (end - start) / (lastIndex - firstIndex + 1);
      // Reversed or not, offsets grow with the index.
      centre = index > lastIndex
          ? end + average * (index - lastIndex - 0.5)
          : start - average * (firstIndex - index - 0.5);
    }
    final c = constraints;
    // Where this sliver starts in the viewport, when it starts inside it.
    final lead = c.viewportMainAxisExtent - c.remainingPaintExtent;
    final windowCentre = c.scrollOffset - lead + c.viewportMainAxisExtent / 2;
    final pixels = c.precedingScrollExtent + c.scrollOffset - lead;
    final maxPixels =
        c.precedingScrollExtent +
        geometry!.scrollExtent -
        c.viewportMainAxisExtent;
    final up = math.max(0.0, maxPixels - pixels);
    final down = math.min(-pixels, up);
    return (
      delta: (centre - windowCentre).clamp(down, up).toDouble(),
      laidOut: laidOut,
    );
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
