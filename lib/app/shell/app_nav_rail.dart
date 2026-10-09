import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_rail_button.dart';
import '../../features/chat/presentation/widgets/chat_rail_button.dart';
import '../../features/dashboard/presentation/widgets/dashboard_rail_button.dart';
import '../../features/notifications/presentation/widgets/notifications_rail_button.dart';
import '../../l10n/app_localizations.dart';

/// The app's narrow left rail: the main destinations (dashboard,
/// notifications, chat, board) on top and integrations at the bottom. The board's workspace tree is a separate
/// panel shown only beside the board.
class AppNavRail extends ConsumerWidget {
  const AppNavRail({super.key});

  /// The rail's width, for panels that open beside it.
  static double widthOf(BuildContext context) =>
      context.spacing.xl6 + context.spacing.xl3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final integrations = ref.watch(integrationsVisibleProvider);
    final view = ref.watch(mainViewProvider);
    return Container(
      width: widthOf(context),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(vertical: s.lg),
      child: Column(
        children: [
          const DashboardRailButton(),
          const NotificationsRailButton(),
          const ChatRailButton(),
          AppRailButton(
            icon: PhosphorIconsLight.kanban,
            selectedIcon: PhosphorIconsFill.kanban,
            label: l.board,
            selected: view == MainView.board && !integrations,
            onTap: () => showBoardView(ref),
          ),
          const Spacer(),
          AppRailButton(
            icon: PhosphorIconsLight.gear,
            selectedIcon: PhosphorIconsLight.gear,
            label: l.integrations,
            selected: integrations,
            onTap: () =>
                ref.read(settingsOpenProvider.notifier).state = !integrations,
          ),
        ],
      ),
    );
  }
}
