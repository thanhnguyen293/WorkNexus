import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';

/// Switches the ZenTao boards between kanban columns and a table. The choice is
/// a setting, so the app reopens in it.
class BoardLayoutToggle extends ConsumerWidget {
  const BoardLayoutToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final layout = ref.watch(appSettingsProvider.select((s) => s.boardLayout));
    final settings = ref.read(appSettingsProvider.notifier);
    return AppSegmentedTabs(
      tabs: [
        AppSegmentedTab(
          label: l.boardLayoutBoard,
          icon: LucideIcons.squareKanban300,
          active: layout == BoardLayout.board,
          onTap: () => settings.setBoardLayout(BoardLayout.board),
        ),
        AppSegmentedTab(
          label: l.boardLayoutTable,
          icon: LucideIcons.table2300,
          active: layout == BoardLayout.table,
          onTap: () => settings.setBoardLayout(BoardLayout.table),
        ),
      ],
    );
  }
}
