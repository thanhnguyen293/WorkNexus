import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

part 'searchable_dropdown_field.parts.dart';
part 'searchable_dropdown_field.leaves.dart';

/// A themed select field with a filterable popover list.
///
/// Renders like the app's input fields when closed; tapping opens an anchored
/// popover with a search box and a scrollable, keyboard-navigable list of
/// [items]. Generic over the item type [T]; the caller supplies [labelOf] for
/// display text and an optional [searchTextOf] for the text matched against the
/// query (defaults to [labelOf]).
class SearchableDropdownField<T> extends StatefulWidget {
  const SearchableDropdownField({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.searchTextOf,
    this.hintText = 'Select…',
    this.searchHint = 'Search…',
    this.emptyLabel = 'No matches',
    this.maxListHeight = 260,
  });

  final List<T> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T item) labelOf;
  final String Function(T item)? searchTextOf;
  final String hintText;
  final String searchHint;
  final String emptyLabel;
  final double maxListHeight;

  @override
  State<SearchableDropdownField<T>> createState() =>
      _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T>
    extends State<SearchableDropdownField<T>> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();

  String _query = '';
  double _fieldWidth = 260;
  int _highlighted = 0;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _searchText(T item) =>
      (widget.searchTextOf ?? widget.labelOf)(item).toLowerCase();

  List<T> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items.where((i) => _searchText(i).contains(q)).toList();
  }

  void _open() {
    final box = context.findRenderObject() as RenderBox?;
    _fieldWidth = box?.size.width ?? 260;
    _search.clear();
    _query = '';
    final current = widget.value;
    _highlighted = current == null ? 0 : widget.items.indexOf(current);
    if (_highlighted < 0) _highlighted = 0;
    _portal.show();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _close() {
    _portal.hide();
    FocusScope.of(context).unfocus();
  }

  void _select(T item) {
    widget.onChanged(item);
    _close();
  }

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;
      _highlighted = 0;
    });
  }

  void _moveHighlight(int delta) {
    final list = _filtered;
    if (list.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, list.length - 1);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final list = _filtered;
      if (list.isNotEmpty && _highlighted < list.length) {
        _select(list[_highlighted]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => _PopupOverlay<T>(
        link: _link,
        fieldWidth: _fieldWidth,
        searchController: _search,
        searchFocus: _searchFocus,
        searchHint: widget.searchHint,
        emptyLabel: widget.emptyLabel,
        maxListHeight: widget.maxListHeight,
        scrollController: _scroll,
        items: _filtered,
        selectedValue: widget.value,
        highlighted: _highlighted,
        labelOf: widget.labelOf,
        onClose: _close,
        onQueryChanged: _onQueryChanged,
        onKey: _onKey,
        onSelect: _select,
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: _ClosedField(
          label: widget.value == null
              ? null
              : widget.labelOf(widget.value as T),
          hintText: widget.hintText,
          onTap: _open,
        ),
      ),
    );
  }
}
