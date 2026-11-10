import 'package:flutter/widgets.dart';

import 'render_board_toolbar.dart';

export 'render_board_toolbar.dart';

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
    final shown = (renderObject as RenderBoardToolbar).shown;
    visitChildren((child) {
      if (shown.contains(child.findRenderObject())) visitor(child);
    });
  }
}
