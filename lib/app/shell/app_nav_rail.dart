import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_rail_button.dart';
import '../../features/chat/presentation/widgets/chat_rail_button.dart';
import '../../l10n/app_localizations.dart';

/// The app's narrow left rail: the main destinations (board, chat) on top
/// and integrations at the bottom. The board's workspace tree is a separate
/// panel shown only beside the board.
class AppNavRail extends ConsumerWidget {
  const AppNavRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final integrations = ref.watch(integrationsVisibleProvider);
    final chat = ref.watch(chatOpenProvider);
    return Container(
      width: s.xl6 + s.xl3,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(vertical: s.lg),
      child: Column(
        children: [
          const ChatRailButton(),
          AppRailButton(
            icon: Icons.view_kanban_outlined,
            selectedIcon: Icons.view_kanban_rounded,
            label: l.board,
            selected: !chat && !integrations,
            onTap: () => showBoardView(ref),
          ),
          const Spacer(),
          AppRailButton(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
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
