import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../core/widgets/unread_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../assigned_counts_provider.dart';

/// The board destination of the app rail, badged with every open ticket
/// assigned to me — the sources tree's total.
class BoardRailButton extends ConsumerWidget {
  const BoardRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(assignedCountsProvider.select((c) => c.total));
    return AppRailButton(
      icon: LucideIcons.squareKanban300,
      label: AppL10n.of(context).board,
      selected: ref.watch(selectedMainViewProvider) == MainView.board,
      onTap: () => ref.read(appNavProvider.notifier).show(MainView.board),
      badge: assigned > 0 ? UnreadBadge(count: assigned) : null,
    );
  }
}
