import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/talker_debug_overlay.dart';
import '../../core/di/providers.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/quick_settings_side_panel.dart';
import '../../features/app_update/presentation/widgets/update_notification_listener.dart';
import '../../features/app_update/presentation/widgets/update_settings_card.dart';
import '../../features/board/presentation/board_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/widgets/chat_appearance_settings.dart';
import '../../features/chat/presentation/widgets/chat_auto_download_settings.dart';
import '../../features/chat/presentation/widgets/chat_notification_listener.dart';
import '../../features/chat/presentation/widgets/chat_notification_settings.dart';
import '../../features/connections/presentation/settings_page.dart';
import '../../features/task_detail/presentation/detail_panel.dart';
import 'app_nav_rail.dart';
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
    final chatOpen = ref.watch(chatOpenProvider);

    return UpdateNotificationListener(
      child: ChatNotificationListener(
        child: Scaffold(
          backgroundColor: c.background,
          body: Column(
            children: [
              TitleBar(assignedCount: assigned),
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        const AppNavRail(),
                        // The workspace tree belongs to the board only.
                        if (!integrationsVisible && !chatOpen)
                          const ResizableSidebar(),
                        Expanded(
                          child: integrationsVisible
                              ? const SettingsPage(footer: UpdateSettingsCard())
                              : chatOpen
                              ? const ChatPage()
                              : const BoardPage(),
                        ),
                      ],
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
    );
  }
}
