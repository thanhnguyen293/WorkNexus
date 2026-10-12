import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_rail_button.dart';
import '../../features/app_update/presentation/widgets/update_rail_button.dart';
import '../../features/chat/presentation/widgets/chat_rail_button.dart';
import '../../features/dashboard/presentation/widgets/dashboard_rail_button.dart';
import '../../features/notifications/presentation/widgets/notifications_rail_button.dart';
import '../../l10n/app_localizations.dart';
import 'new_ticket_menu.dart';

/// The app's narrow left rail, in three groups: the "+ new" action on top, the
/// places you work in (dashboard, board, chat), and the global utilities
/// (notifications, update, integrations) at the bottom. The board's workspace
/// tree is a separate panel shown only beside the board.
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
    final view = ref.watch(selectedMainViewProvider);
    return Container(
      width: widthOf(context),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(vertical: s.lg),
      child: Column(
        children: [
          // The one action: create. Set apart from the places below it.
          const NewTicketRailButton(),
          // Places you work in, by how often you go there.
          const DashboardRailButton(),
          AppRailButton(
            icon: LucideIcons.squareKanban300,
            label: l.board,
            selected: view == MainView.board,
            onTap: () => ref.read(appNavProvider.notifier).show(MainView.board),
          ),
          const ChatRailButton(),
          const Spacer(),
          // Global utilities: panels, the updater and settings.
          const AppRailDivider(),
          const NotificationsRailButton(),
          const UpdateRailButton(),
          AppRailButton(
            icon: LucideIcons.settings300,
            label: l.integrations,
            selected: integrations,
            onTap: () => ref.read(appNavProvider.notifier).toggleSettings(),
          ),
        ],
      ),
    );
  }
}
