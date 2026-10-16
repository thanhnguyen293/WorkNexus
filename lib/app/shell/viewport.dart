import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/domain/value_objects/account_sync_status.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../core/widgets/app_state_view.dart';
import '../../features/app_update/presentation/widgets/update_settings_card.dart';
import '../../features/connections/presentation/settings_page.dart';
import '../../features/connections/presentation/widgets/local_cache_card.dart';
import '../../features/mini_apps/presentation/widgets/mini_app_settings_card.dart';
import '../../features/mini_apps/presentation/widgets/mini_apps_host.dart';
import '../../features/ticket_editor/presentation/pages/ticket_editor_page.dart';
import '../../features/translation/presentation/widgets/translation_settings_card.dart';
import '../../features/workspace_overview/presentation/pages/integrations_page.dart';
import '../../features/workspace_overview/presentation/pages/members_page.dart';
import '../../features/workspace_overview/presentation/pages/overview_page.dart';
import 'auth_expired_banner.dart';
import 'section_error_boundary.dart';

/// Main viewport hosting workspace views, tool sections, or ticket editor (specs S5, S6).
/// Keys sections by `(accountId, sectionId)` and keeps the last 3 alive with
/// LRU IndexedStack caching (design §9).
class Viewport extends ConsumerStatefulWidget {
  const Viewport({super.key});

  @override
  ConsumerState<Viewport> createState() => _ViewportState();
}

class _CachedSection {
  _CachedSection({
    required this.key,
    required this.widget,
    required this.lastUsed,
  });
  final String key;
  final Widget widget;
  final int lastUsed;
}

class _ViewportState extends ConsumerState<Viewport> {
  static const int _maxCachedSections = 3;
  final List<_CachedSection> _cache = [];

  int _uses = 0;

  /// Each section keeps its slot until it is evicted: [IndexedStack] matches
  /// its children by position (it wraps them, so keys do not help), and a
  /// section moved to another slot would be rebuilt from scratch rather than
  /// kept alive. The least recently used section's slot is the one reused.
  void _updateCache(String key, Widget widget) {
    final entry = _CachedSection(key: key, widget: widget, lastUsed: ++_uses);
    final existingIndex = _cache.indexWhere((item) => item.key == key);
    if (existingIndex >= 0) {
      _cache[existingIndex] = entry;
    } else if (_cache.length < _maxCachedSections) {
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
    final c = context.colors;
    final nav = ref.watch(appNavProvider);
    final editor = ref.watch(ticketEditorProvider);

    final Widget content;
    if (editor != null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 560),
        child: ColoredBox(
          color: c.background,
          child: TicketEditorPage(route: editor),
        ),
      );
    } else {
      final (key, sectionWidget) = _resolveActiveSection(context, ref, nav);
      _updateCache(key, sectionWidget);
      final currentIndex = _cache.indexWhere((item) => item.key == key);
      content = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 560),
        child: ColoredBox(
          color: c.background,
          child: IndexedStack(
            index: currentIndex >= 0 ? currentIndex : 0,
            children: [
              for (var i = 0; i < _cache.length; i++)
                TickerMode(
                  key: ValueKey(_cache[i].key),
                  enabled: i == currentIndex,
                  child: Focus(
                    canRequestFocus: i == currentIndex,
                    child: _cache[i].widget,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // The mini apps stay mounted whatever is on screen: each is a running
    // page (and the host routes their links and notification taps).
    final miniAppOnScreen = ref.watch(miniAppOnScreenProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: miniAppOnScreen,
          child: TickerMode(enabled: !miniAppOnScreen, child: content),
        ),
        const MiniAppsHost(),
      ],
    );
  }

  (String, Widget) _resolveActiveSection(
    BuildContext context,
    WidgetRef ref,
    AppNavState nav,
  ) {
    return switch (nav.rail) {
      WorkspaceTarget() => _buildWorkspaceSection(
        context,
        nav.workspaceSection,
      ),
      AccountTarget(:final accountId) => _buildAccountSection(
        context,
        ref,
        accountId,
        nav,
      ),
    };
  }

  (String, Widget) _buildWorkspaceSection(
    BuildContext context,
    WorkspaceSection section,
  ) {
    final key = 'workspace:${section.name}';
    final Widget page = switch (section) {
      WorkspaceSection.overview => const OverviewPage(),
      WorkspaceSection.integrations => const IntegrationsPage(),
      WorkspaceSection.members => const MembersPage(),
      WorkspaceSection.settings => SettingsPage(
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TranslationSettingsCard(),
            SizedBox(height: context.spacing.xl4),
            const MiniAppSettingsCard(),
            SizedBox(height: context.spacing.xl4),
            const UpdateSettingsCard(),
            SizedBox(height: context.spacing.xl4),
            const LocalCacheCard(),
          ],
        ),
      ),
    };

    return (key, SectionErrorBoundary(key: ValueKey(key), child: page));
  }

  (String, Widget) _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    String accountId,
    AppNavState nav,
  ) {
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    Account? account;
    for (final a in accounts) {
      if (a.id == accountId) {
        account = a;
        break;
      }
    }

    if (account == null) {
      final key = 'account:$accountId:not_found';
      return (
        key,
        SectionErrorBoundary(
          key: ValueKey(key),
          child: const AppStateView.empty(title: 'Account not found'),
        ),
      );
    }

    final registry = ref.watch(toolRegistryProvider);
    final module = registry[account.providerType];
    if (module == null) {
      final key = 'account:$accountId:no_module';
      return (
        key,
        SectionErrorBoundary(
          key: ValueKey(key),
          child: const AppStateView.empty(title: 'Tool module not found'),
        ),
      );
    }

    final location =
        nav.locations[accountId] ??
        ToolLocation(section: module.defaultSection);
    final key = '$accountId:${location.section.value}';

    final syncStatus = ref.watch(syncStatusProvider(accountId)).asData?.value;
    final isAuthExpired = syncStatus is SyncAuthExpired;

    final sectionBody = Column(
      children: [
        if (isAuthExpired) AuthExpiredBanner(account: account),
        Expanded(child: module.buildSection(context, account, location)),
      ],
    );

    return (key, SectionErrorBoundary(key: ValueKey(key), child: sectionBody));
  }
}
