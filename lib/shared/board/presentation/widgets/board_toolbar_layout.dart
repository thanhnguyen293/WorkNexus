import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The pieces of a [BoardToolbarLayout]. [scopesMenu] and [modesCompact] are
/// the narrow forms of [scopes] and [modes].
enum BoardToolbarSlot {
  scopes,
  scopesMenu,
  filters,
  refresh,
  modes,
  modesCompact,
}

/// Lays a board toolbar out on one row — scopes and filters on the left,
/// refresh and view modes on the right — folding it as the row narrows
/// instead of overflowing: first the view modes go icon-only, then the
/// scopes fold into a menu. Every piece is built (so the choice needs no
/// extra frame), only the chosen ones are painted and hit.
class BoardToolbarLayout
    extends SlottedMultiChildRenderObjectWidget<BoardToolbarSlot, RenderBox> {
  const BoardToolbarLayout({
    super.key,
    required this.gap,
    this.scopes,
    this.scopesMenu,
    this.filters,
    required this.refresh,
    required this.modes,
    required this.modesCompact,
  });

  final double gap;
  final Widget? scopes;
  final Widget? scopesMenu;
  final Widget? filters;
  final Widget refresh;
  final Widget modes;
  final Widget modesCompact;

  @override
  Iterable<BoardToolbarSlot> get slots => BoardToolbarSlot.values;

  @override
  Widget? childForSlot(BoardToolbarSlot slot) => switch (slot) {
    BoardToolbarSlot.scopes => scopes,
    BoardToolbarSlot.scopesMenu => scopesMenu,
    BoardToolbarSlot.filters => filters,
    BoardToolbarSlot.refresh => refresh,
    BoardToolbarSlot.modes => modes,
    BoardToolbarSlot.modesCompact => modesCompact,
  };

  @override
  RenderBoardToolbar createRenderObject(BuildContext context) =>
      RenderBoardToolbar(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBoardToolbar renderObject,
  ) {
    renderObject.gap = gap;
  }

  @override
  SlottedRenderObjectElement<BoardToolbarSlot, RenderBox> createElement() =>
      _BoardToolbarElement(this);
}

class _BoardToolbarElement
    extends SlottedRenderObjectElement<BoardToolbarSlot, RenderBox> {
  _BoardToolbarElement(super.widget);

  // Finders and the inspector see only the form that fits, as with
  // Offstage: the folded-away forms are built but not on screen.
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final shown = (renderObject as RenderBoardToolbar)._shown;
    visitChildren((child) {
      if (shown.contains(child.findRenderObject())) visitor(child);
    });
  }
}

class RenderBoardToolbar extends RenderBox
    with SlottedContainerRenderObjectMixin<BoardToolbarSlot, RenderBox> {
  RenderBoardToolbar(this._gap);

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// Widest first: the first that fits is used, else the last.
  static const _layouts = [
    (
      [BoardToolbarSlot.scopes, BoardToolbarSlot.filters],
      [BoardToolbarSlot.refresh, BoardToolbarSlot.modes],
    ),
    (
      [BoardToolbarSlot.scopes, BoardToolbarSlot.filters],
      [BoardToolbarSlot.refresh, BoardToolbarSlot.modesCompact],
    ),
    (
      [BoardToolbarSlot.scopesMenu, BoardToolbarSlot.filters],
      [BoardToolbarSlot.refresh, BoardToolbarSlot.modesCompact],
    ),
  ];

  List<RenderBox> _shown = const [];

  (List<RenderBox>, List<RenderBox>) _boxes(
    (List<BoardToolbarSlot>, List<BoardToolbarSlot>) layout,
  ) => (
    [for (final slot in layout.$1) ?childForSlot(slot)],
    [for (final slot in layout.$2) ?childForSlot(slot)],
  );

  double _rowWidth(Iterable<double> widths) => widths.isEmpty
      ? 0
      : widths.reduce((a, b) => a + b) + _gap * (widths.length - 1);

  double _intrinsicWidth(
    (List<BoardToolbarSlot>, List<BoardToolbarSlot>) layout,
  ) {
    final (left, right) = _boxes(layout);
    return _rowWidth([
      for (final box in [...left, ...right])
        box.getMaxIntrinsicWidth(double.infinity),
    ]);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(_layouts.last);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(_layouts.first);

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => children.fold(
    0,
    (h, box) => math.max(h, box.getMaxIntrinsicHeight(double.infinity)),
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final natural = BoxConstraints(maxHeight: constraints.maxHeight);
    final height = children.fold(
      0.0,
      (h, box) => math.max(h, box.getDryLayout(natural).height),
    );
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : computeMaxIntrinsicWidth(height),
        height,
      ),
    );
  }

  @override
  void performLayout() {
    // Each piece at its own width first: that is what decides the fold.
    final natural = BoxConstraints(maxHeight: constraints.maxHeight);
    for (final box in children) {
      box.layout(natural, parentUsesSize: true);
    }
    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;

    var (left, right) = _boxes(_layouts.last);
    for (final layout in _layouts) {
      final (l, r) = _boxes(layout);
      if (_rowWidth([
            for (final b in [...l, ...r]) b.size.width,
          ]) <=
          maxWidth) {
        (left, right) = (l, r);
        break;
      }
    }

    final rightWidth = _rowWidth([for (final b in right) b.size.width]);
    var height = 0.0;
    for (final box in [...left, ...right]) {
      height = math.max(height, box.size.height);
    }
    size = constraints.constrain(
      Size(
        maxWidth.isFinite
            ? maxWidth
            : _rowWidth([
                for (final b in [...left, ...right]) b.size.width,
              ]),
        height,
      ),
    );

    var x = 0.0;
    for (final box in left) {
      _place(box, x);
      x += box.size.width + _gap;
    }
    x = size.width - rightWidth;
    for (final box in right) {
      _place(box, x);
      x += box.size.width + _gap;
    }
    _shown = [...left, ...right];
  }

  void _place(RenderBox box, double x) {
    (box.parentData! as BoxParentData).offset = Offset(
      x,
      (size.height - box.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final box in _shown) {
      context.paintChild(
        box,
        offset + (box.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final box in _shown.reversed) {
      final offset = (box.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, local) => box.hitTest(result, position: local),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      _shown.forEach(visitor);
}
