import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/board_providers.dart';

/// The board with no tickets to show. "Your filters hid everything" (with a
/// Clear all) and "nothing has synced here yet" are different messages.
class EmptyState extends ConsumerWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final filtered = ref.watch(
      filterStateProvider.select((f) => f.hasActiveFilters),
    );
    if (!filtered) {
      return AppStateView.empty(
        icon: LucideIcons.kanban300,
        title: l.boardEmptyTitle,
        message: l.boardEmptyDesc,
      );
    }
    return AppStateView.empty(
      icon: LucideIcons.searchX300,
      title: l.emptyTitle,
      message: l.emptyDesc,
      action: AppButton.filled(
        size: AppButtonSize.small,
        onPressed: () => ref.read(filterStateProvider.notifier).clearAll(),
        child: Text(l.clearAllFilters),
      ),
    );
  }
}
