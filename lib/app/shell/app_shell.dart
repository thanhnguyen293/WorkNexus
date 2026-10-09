import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/talker_debug_overlay.dart';
import '../../core/di/providers.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/navigation/ticket_editor_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/quick_settings_side_panel.dart';
import '../../features/app_update/presentation/widgets/update_notification_listener.dart';
import '../../features/app_update/presentation/widgets/update_settings_card.dart';
import '../../features/board/presentation/board_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../features/chat/presentation/widgets/chat_appearance_settings.dart';
import '../../features/chat/presentation/widgets/chat_auto_download_settings.dart';
import '../../features/chat/presentation/widgets/chat_notification_listener.dart';
import '../../features/chat/presentation/widgets/chat_notification_settings.dart';
import '../../features/connections/presentation/settings_page.dart';
import '../../features/connections/presentation/widgets/zentao_profile_dialog.dart';
import '../../features/connections/presentation/widgets/zentao_profile_startup.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/notifications/presentation/widgets/notifications_panel.dart';
import '../../features/task_detail/presentation/detail_panel.dart';
import '../../features/ticket_editor/presentation/pages/ticket_editor_page.dart';
import '../../features/translation/presentation/widgets/translation_settings_card.dart';
import 'app_nav_rail.dart';
import 'new_ticket_menu.dart';
import 'resizable_sidebar.dart';
import 'title_bar.dart';

/// Top-level window layout: custom title bar, sidebar + main area, and the
/// right-side task-detail slide-over and Quick Settings panel overlaid on
/// top.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final assigned = ref.watch(ticketsProvider).asData?.value.length;
    final integrationsVisible = ref.watch(integrationsVisibleProvider);
    final view = ref.watch(mainViewProvider);
    // A bug / task editor takes the whole area beside the rail.
    final editor = integrationsVisible ? null : ref.watch(ticketEditorProvider);

    return UpdateNotificationListener(
      child: ChatNotificationListener(
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
                          // The workspace tree belongs to the board only.
                          if (!integrationsVisible &&
                              editor == null &&
                              view == MainView.board)
                            const ResizableSidebar(),
                          Expanded(
                            child: integrationsVisible
                                ? SettingsPage(
                                    footer: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const TranslationSettingsCard(),
                                        SizedBox(height: context.spacing.xl4),
                                        const UpdateSettingsCard(),
                                      ],
                                    ),
                                  )
                                : editor != null
                                ? TicketEditorPage(route: editor)
                                : switch (view) {
                                    MainView.dashboard => const DashboardPage(),
                                    MainView.chat => ChatPage(
                                      onViewProfile:
                                          (dialogContext, accountId) {
                                            for (final account in ref.read(
                                              chatAccountsProvider,
                                            )) {
                                              if (account.id == accountId) {
                                                ZenTaoProfileDialog.show(
                                                  dialogContext,
                                                  account,
                                                );
                                                break;
                                              }
                                            }
                                          },
                                    ),
                                    MainView.board => const BoardPage(),
                                  },
                          ),
                        ],
                      ),
                      NotificationsPanel(
                        leftInset: AppNavRail.widthOf(context),
                      ),
                      const DetailOverlay(),
                      const QuickSettingsSidePanel(
                        sections: [
                          ChatAppearanceSettings(),
                          ChatAutoDownloadSettings(),
                          ChatNotificationSettings(),
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
    );
  }
}
