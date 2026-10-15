import 'package:flutter/material.dart' hide Viewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/talker_debug_overlay.dart';
import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../core/widgets/quick_settings_side_panel.dart';
import '../../features/chat/presentation/widgets/chat_app_badge.dart';
import '../../features/chat/presentation/widgets/chat_appearance_settings.dart';
import '../../features/chat/presentation/widgets/chat_auto_download_settings.dart';
import '../../features/chat/presentation/widgets/chat_notification_listener.dart';
import '../../features/chat/presentation/widgets/chat_notification_settings.dart';
import '../../features/chat/presentation/widgets/chat_privacy_settings.dart';
import '../../features/chat/presentation/widgets/sticker_import_listener.dart';
import '../../features/chat/presentation/widgets/ticket_link_handler.dart';
import '../../features/connections/presentation/widgets/local_cache_quick_settings.dart';
import '../../features/connections/presentation/widgets/zentao_profile_startup.dart';
import '../../features/notifications/presentation/widgets/notifications_panel.dart';
import '../../features/workspace_overview/presentation/widgets/workspace_nav_pane.dart';
import '../../shared/detail/presentation/detail_panel.dart';
import 'app_nav_rail.dart';
import 'new_ticket_menu.dart';
import 'title_bar.dart';
import 'viewport.dart';

/// Top-level unified workspace shell (specs S1.1).
/// Layout: TitleBar on top; Row with Rail (76px) | Tool Pane (300px) | Viewport (flex);
/// Stack overlay with notifications, slide-over detail, and quick settings.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sortedActiveAccountsProvider, (previous, next) {
      final registry = ref.read(toolRegistryProvider);
      ref
          .read(appNavProvider.notifier)
          .selectDefaultAppIfApplicable(accounts: next, registry: registry);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final accounts = ref.read(sortedActiveAccountsProvider);
      final registry = ref.read(toolRegistryProvider);
      ref
          .read(appNavProvider.notifier)
          .selectDefaultAppIfApplicable(accounts: accounts, registry: registry);
    });

    final c = context.colors;
    final assigned = ref.watch(ticketsProvider).asData?.value.length;
    final nav = ref.watch(appNavProvider);
    final editor = ref.watch(ticketEditorProvider);

    return TicketLinkHandler(
      child: ChatNotificationListener(
        child: ChatAppBadge(
          child: StickerImportListener(
            child: Scaffold(
              backgroundColor: c.background,
              body: NewTicketShortcut(
                child: Column(
                  children: [
                    TitleBar(assignedCount: assigned),
                    Expanded(
                      child: Stack(
                        children: [
                          const ZenTaoProfileStartup(),
                          Row(
                            children: [
                              const AppNavRail(),
                              if (editor == null) _ToolPane(nav: nav),
                              const Expanded(child: Viewport()),
                            ],
                          ),
                          NotificationsPanel(
                            leftInset: AppNavRail.widthOf(context),
                          ),
                          const DetailOverlay(),
                          const QuickSettingsSidePanel(
                            generalSections: [LocalCacheQuickSettings()],
                            chatSections: [
                              ChatAppearanceSettings(),
                              ChatAutoDownloadSettings(),
                              ChatNotificationSettings(),
                              ChatPrivacySettings(),
                            ],
                          ),
                          const TalkerDebugOverlay(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolPane extends ConsumerWidget {
  const _ToolPane({required this.nav});

  final AppNavState nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (nav.rail) {
      WorkspaceTarget() => const WorkspaceNavPane(),
      AccountTarget(:final accountId) => _buildAccountPane(
        context,
        ref,
        accountId,
      ),
    };
  }

  Widget _buildAccountPane(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) {
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    Account? account;
    for (final a in accounts) {
      if (a.id == accountId) {
        account = a;
        break;
      }
    }
    if (account == null) return const SizedBox.shrink();

    final registry = ref.watch(toolRegistryProvider);
    final module = registry[account.providerType];
    if (module == null) return const SizedBox.shrink();

    final location =
        nav.locations[accountId] ??
        ToolLocation(section: module.defaultSection);
    return module.buildNavPane(context, account, location);
  }
}
