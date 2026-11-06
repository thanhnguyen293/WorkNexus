import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The pieces of a [BoardToolbarLayout]. [scopesMenu] and [modesCompact] are
/// the narrow forms of [scopes] and [modes].
enum BoardToolbarSlot {
  scopes,
  scopesMenu,
  filters,
  search,
  refresh,
  modes,
  modesCompact,
}

/// Lays a board toolbar out on one row — scopes and filters on the left,
/// refresh and view modes on the right, [search] filling the room between
/// them — folding it as the row narrows instead of overflowing: first the
/// view modes go icon-only, then the scopes fold into a menu, and only when
/// even that leaves no room does the search go. Every piece is built (so
/// the choice needs no extra frame), only the chosen ones are painted and
/// hit.
class BoardToolbarLayout
    extends SlottedMultiChildRenderObjectWidget<BoardToolbarSlot, RenderBox> {
  const BoardToolbarLayout({
    super.key,
    required this.gap,
    this.scopes,
    this.scopesMenu,
    this.filters,
    this.search,
    required this.refresh,
    required this.modes,
    required this.modesCompact,
  });

  final double gap;
  final Widget? scopes;
  final Widget? scopesMenu;
  final Widget? filters;

  /// Laid out at the width it is given (never its own), between
  /// [RenderBoardToolbar.searchMinWidth] and
  /// [RenderBoardToolbar.searchMaxWidth].
  final Widget? search;
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
    BoardToolbarSlot.search => search,
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

  /// Narrower than this, the search leaves the row instead of squeezing.
  static const searchMinWidth = 160.0;
  static const searchMaxWidth = 480.0;

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

  RenderBox? get _search => childForSlot(BoardToolbarSlot.search);

  /// Every piece but the search, which takes its width from the row.
  Iterable<RenderBox> get _sized => children.where((box) => box != _search);

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
      _intrinsicWidth(_layouts.first) +
      (_search == null ? 0 : _gap + searchMaxWidth);

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _sized.fold(
    0,
    (h, box) => math.max(h, box.getMaxIntrinsicHeight(double.infinity)),
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final natural = BoxConstraints(maxHeight: constraints.maxHeight);
    final height = _sized.fold(
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
    for (final box in _sized) {
      box.layout(natural, parentUsesSize: true);
    }
    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;
    final search = _search;
    double width(List<RenderBox> boxes) =>
        _rowWidth([for (final b in boxes) b.size.width]);

    // The widest form that still leaves the search its minimum, else the
    // widest that fits without it, else the narrowest.
    var (left, right) = _boxes(_layouts.last);
    var withSearch = false;
    for (final wantSearch in [if (search != null) true, false]) {
      final extra = wantSearch ? _gap + searchMinWidth : 0;
      final fit = _layouts
          .map(_boxes)
          .where((form) => width([...form.$1, ...form.$2]) + extra <= maxWidth);
      if (fit.isNotEmpty) {
        (left, right) = fit.first;
        withSearch = wantSearch;
        break;
      }
    }

    final leftWidth = width(left);
    final rightWidth = width(right);
    var searchWidth = 0.0;
    if (withSearch && search != null) {
      final room =
          maxWidth - leftWidth - rightWidth - _gap * (left.isEmpty ? 1 : 2);
      searchWidth = room.isFinite
          ? math.min(room, searchMaxWidth)
          : searchMaxWidth;
      search.layout(
        BoxConstraints.tightFor(width: searchWidth).enforce(natural),
        parentUsesSize: true,
      );
    }

    var height = 0.0;
    for (final box in [...left, ...right, if (withSearch) ?search]) {
      height = math.max(height, box.size.height);
    }
    size = constraints.constrain(
      Size(
        maxWidth.isFinite
            ? maxWidth
            : _rowWidth([
                for (final b in [...left, ...right]) b.size.width,
                if (withSearch) searchWidth,
              ]),
        height,
      ),
    );

    var x = 0.0;
    for (final box in left) {
      _place(box, x);
      x += box.size.width + _gap;
    }
    if (withSearch && search != null) _place(search, x);
    x = size.width - rightWidth;
    for (final box in right) {
      _place(box, x);
      x += box.size.width + _gap;
    }
    _shown = [...left, if (withSearch) ?search, ...right];
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
