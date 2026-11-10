import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/navigation/collapsed_panes.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../l10n/app_localizations.dart';
import 'chat_place.dart';
import 'collapsible_pane.dart';
import 'settings_nav_pane.dart';

/// The column beside the rail (the tool pane), kept alive per place like the
/// [Viewport]'s sections: going to Bugs and back to Docs — or to Tasks and
/// back to the chat — finds the column as it was left (scroll, filter, open
/// branches) instead of rebuilt from scratch.
///
/// The last [_maxCached] places stay mounted; the ones not on screen are
/// offstage (no size, no ticking, no focus). [hidden] keeps them all mounted
/// but out of sight while the editor or a mini app takes the area.
class ToolPaneHost extends ConsumerStatefulWidget {
  const ToolPaneHost({super.key, required this.nav, required this.hidden});

  final AppNavState nav;
  final bool hidden;

  @override
  ConsumerState<ToolPaneHost> createState() => _ToolPaneHostState();
}

class _CachedPane {
  const _CachedPane(this.key, this.widget, this.lastUsed);

  final String key;
  final Widget widget;
  final int lastUsed;
}

class _ToolPaneHostState extends ConsumerState<ToolPaneHost> {
  static const _maxCached = 5;
  final List<_CachedPane> _cache = [];
  int _uses = 0;

  /// Like the viewport's: a pane keeps its slot until evicted, since a pane
  /// moved to another slot would be rebuilt rather than kept.
  void _remember(String key, Widget pane) {
    final entry = _CachedPane(key, pane, ++_uses);
    final at = _cache.indexWhere((p) => p.key == key);
    if (at >= 0) {
      _cache[at] = entry;
    } else if (_cache.length < _maxCached) {
      _cache.add(entry);
    } else {
      var oldest = 0;
      for (var i = 1; i < _cache.length; i++) {
        if (_cache[i].lastUsed < _cache[oldest].lastUsed) oldest = i;
      }
      _cache[oldest] = entry;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _resolve(widget.nav);
    if (current != null) _remember(current.$1, current.$2);
    final shown = widget.hidden ? null : current?.$1;

    // A Stack of Offstage panes sizes to the one on screen (an offstage
    // child takes no room), so the column keeps that pane's own width.
    return Stack(
      children: [
        for (final pane in _cache)
          Offstage(
            key: ValueKey(pane.key),
            offstage: pane.key != shown,
            child: TickerMode(
              enabled: pane.key == shown,
              child: Focus(
                canRequestFocus: pane.key == shown,
                child: pane.widget,
              ),
            ),
          ),
      ],
    );
  }

  /// The place's cache key and its pane; null for a place without one (the
  /// dashboard) or an account not loaded yet.
  (String, Widget)? _resolve(AppNavState nav) => switch (nav.rail) {
    WorkspaceTarget() => null,
    SettingsTarget() => ('settings', const SettingsNavPane()),
    ChatTarget() => ('chat', const ChatToolPane()),
    AccountTarget(:final accountId) => _accountPane(nav, accountId),
  };

  (String, Widget)? _accountPane(AppNavState nav, String accountId) {
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    Account? account;
    for (final a in accounts) {
      if (a.id == accountId) {
        account = a;
        break;
      }
    }
    if (account == null) return null;
    final module = ref.watch(toolRegistryProvider)[account.providerType];
    if (module == null) return null;
    final location =
        nav.locations[accountId] ??
        ToolLocation(section: module.defaultSection);
    final pane = module.buildNavPane(context, account, location);
    final key = paneKey(accountId, location.section);
    return (
      key,
      switch (module.sections
          .where((sec) => sec.id == location.section)
          .firstOrNull) {
        final section? when module.paneCollapsible(location) => CollapsiblePane(
          paneKey: key,
          icon: section.icon,
          label: section.label(AppL10n.of(context)),
          child: pane,
        ),
        _ => pane,
      },
    );
  }
}
