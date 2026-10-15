import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/domain/entities/ticket.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/board/domain/usecases/search_local_tickets.dart';
import 'search_results_overlay.dart';
import 'search_trailing_affordance.dart';

/// Contextual search field in the title bar (design §7, specs S2.3).
/// Features 150ms debounce, Ctrl/Cmd+K global focus, contextual placeholder,
/// keyboard navigation (↑/↓/Enter/Esc), and anchors [SearchResultsOverlay].
class ContextualSearchField extends ConsumerStatefulWidget {
  const ContextualSearchField({super.key});

  @override
  ConsumerState<ContextualSearchField> createState() =>
      _ContextualSearchFieldState();
}

class _ContextualSearchFieldState extends ConsumerState<ContextualSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  static const _searchRegionGroup = 'contextual_search_region';

  Timer? _debounceTimer;
  List<Ticket> _results = const [];
  int _highlightIndex = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isMetaOrControl =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isMetaOrControl && event.logicalKey == LogicalKeyboardKey.keyK) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      if (_controller.text.trim().isNotEmpty && !_portal.isShowing) {
        _portal.show();
      }
      return true;
    }
    return false;
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _executeSearch(query);
    });
  }

  void _executeSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _highlightIndex = 0;
      });
      _portal.hide();
      return;
    }

    final nav = ref.read(appNavProvider);
    final accountId = switch (nav.rail) {
      AccountTarget(:final accountId) => accountId,
      WorkspaceTarget() => null,
    };
    final tickets = ref.read(ticketsProvider).asData?.value ?? const <Ticket>[];

    final matches = const SearchLocalTickets().call(
      SearchLocalTicketsInput(
        tickets: tickets,
        query: trimmed,
        accountId: accountId,
      ),
    );

    setState(() {
      _results = matches;
      _highlightIndex = 0;
    });

    if (!_portal.isShowing) {
      _portal.show();
    }
  }

  void _clearAndClose() {
    _controller.clear();
    _portal.hide();
    _focusNode.unfocus();
    setState(() {
      _results = const [];
      _highlightIndex = 0;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_controller.text.isNotEmpty) {
        _controller.clear();
        _onQueryChanged('');
      } else {
        _focusNode.unfocus();
      }
      _portal.hide();
      return KeyEventResult.handled;
    }

    if (!_portal.isShowing || _results.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightIndex = (_highlightIndex + 1) % _results.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightIndex =
            (_highlightIndex - 1 + _results.length) % _results.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightIndex >= 0 && _highlightIndex < _results.length) {
        final ticket = _results[_highlightIndex];
        ref.read(appNavProvider.notifier).openTicket(ticket.id);
        _clearAndClose();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);
    final nav = ref.watch(appNavProvider);
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    ref.watch(ticketsProvider);

    final placeholder = _resolvePlaceholder(l, nav, accounts);

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => TapRegion(
        groupId: _searchRegionGroup,
        onTapOutside: (_) => _portal.hide(),
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(0, context.sizes.controlMd + s.xs),
          child: Align(
            alignment: Alignment.topLeft,
            child: SearchResultsOverlay(
              results: _results,
              highlightIndex: _highlightIndex,
              width: 480,
              onSelect: (ticket) {
                ref.read(appNavProvider.notifier).openTicket(ticket.id);
                _clearAndClose();
              },
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: TapRegion(
          groupId: _searchRegionGroup,
          child: Focus(
            onKeyEvent: _handleKeyEvent,
            child: Container(
              height: context.sizes.controlMd,
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(r.md),
                border: Border.all(color: c.border),
              ),
              padding: EdgeInsets.symmetric(horizontal: s.sm),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search300,
                    size: context.sizes.iconSm,
                    color: c.textTertiary,
                  ),
                  SizedBox(width: s.sm),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: context.typography.bodySm.copyWith(
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: context.typography.bodySm.copyWith(
                          color: c.textTertiary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onQueryChanged,
                      onTap: () {
                        if (_controller.text.trim().isNotEmpty &&
                            !_portal.isShowing) {
                          _portal.show();
                        }
                      },
                    ),
                  ),
                  SearchTrailingAffordance(
                    hasText: _controller.text.isNotEmpty,
                    onClear: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolvePlaceholder(
    AppL10n l,
    AppNavState nav,
    List<Account> accounts,
  ) {
    return switch (nav.rail) {
      WorkspaceTarget() => l.searchContextWorkspace,
      AccountTarget(:final accountId) => _accountPlaceholder(
        l,
        accountId,
        accounts,
      ),
    };
  }

  String _accountPlaceholder(
    AppL10n l,
    String accountId,
    List<Account> accounts,
  ) {
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return l.searchContextWorkspace;
    return l.searchContextTool(account.providerType.displayName);
  }
}
