import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/debug/talker_debug_overlay.dart';
import '../../core/di/providers.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../features/board/presentation/board_page.dart';
import '../../features/board/presentation/widgets/sidebar.dart';
import '../../features/connections/presentation/settings_page.dart';
import '../../features/task_detail/presentation/detail_panel.dart';
import 'title_bar.dart';

/// Top-level window layout: custom title bar, sidebar + main area, and the
/// right-side task-detail slide-over overlaid on top.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final assigned = ref.watch(ticketsProvider).asData?.value.length;
    final settingsOpen = ref.watch(settingsOpenProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          TitleBar(assignedCount: assigned),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    const SidebarView(),
                    Expanded(
                      child: settingsOpen
                          ? const SettingsPage()
                          : const BoardPage(),
                    ),
                  ],
                ),
                const DetailOverlay(),
                const TalkerDebugOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
