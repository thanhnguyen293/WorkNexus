import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A bubble's [content] (name, quote, text, translation) over its link
/// [cards] and [footer], with the cards as wide as the widest of the
/// content, the footer and their own natural width — the bubble is sized to
/// what it holds and the cards then fill it.
///
/// What an `IntrinsicWidth` around the whole column did, except that the
/// content is laid out for real rather than measured: a Markdown list in the
/// text is drawn by widgets that can only be laid out, and measuring them
/// failed (an assertion in debug builds, a zero width in release).
class MessageFitCards extends MultiChildRenderObjectWidget {
  MessageFitCards({
    super.key,
    required Widget content,
    required Widget cards,
    Widget? footer,
  }) : super(children: [content, cards, ?footer]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMessageFitCards(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMessageFitCards renderObject,
  ) => renderObject.textDirection = Directionality.of(context);
}

class _FitCardsParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object of [MessageFitCards].
class RenderMessageFitCards extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FitCardsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FitCardsParentData> {
  RenderMessageFitCards(this._textDirection);

  /// Which side the children line up with (the start, as in a Column).
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitCardsParentData) {
      child.parentData = _FitCardsParentData();
    }
  }

  List<RenderBox> get _children => getChildrenAsList();

  @override
  void performLayout() {
    final [content, cards, ...rest] = _children;
    final footer = rest.firstOrNull;
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxWidth);
    content.layout(loose, parentUsesSize: true);
    footer?.layout(loose, parentUsesSize: true);
    // The cards hold plain text and pictures, which can be measured.
    final widest = [
      content.size.width,
      footer?.size.width ?? 0,
      cards.getMaxIntrinsicWidth(double.infinity),
    ].reduce(math.max);
    final width = constraints.constrainWidth(math.min(widest, maxWidth));
    cards.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);

    var y = 0.0;
    for (final child in [content, cards, ?footer]) {
      final x = textDirection == TextDirection.rtl
          ? width - child.size.width
          : 0.0;
      (child.parentData! as _FitCardsParentData).offset = Offset(x, y);
      y += child.size.height;
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _children.map((c) => c.getMinIntrinsicWidth(height)).reduce(math.max);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _children.map((c) => c.getMaxIntrinsicWidth(height)).reduce(math.max);

  @override
  double computeMinIntrinsicHeight(double width) => _children
      .map((c) => c.getMinIntrinsicHeight(width))
      .fold(0, (a, b) => a + b);

  @override
  double computeMaxIntrinsicHeight(double width) => _children
      .map((c) => c.getMaxIntrinsicHeight(width))
      .fold(0, (a, b) => a + b);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
