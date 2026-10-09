import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'board_view_tabs.dart';

/// "+ Bug" on a product's bug board, "+ Task" on an execution's task board:
/// opens the editor on a new one there. Nothing on other boards.
class NewTicketButton extends ConsumerWidget {
  const NewTicketButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final (label, route) = switch (ref.watch(viewModeProvider)) {
      ViewMode.zentaoBugs => switch (ref.watch(selectedZenTaoProductProvider)) {
        final p? => (
          l.newBug,
          NewBugRoute(accountId: p.accountId, productId: p.productId),
        ),
        null => (null, null),
      },
      ViewMode.zentaoTasks => switch (ref.watch(
        selectedZenTaoExecutionProvider,
      )) {
        final e? => (
          l.newTask,
          NewTaskRoute(accountId: e.accountId, executionId: e.executionId),
        ),
        null => (null, null),
      },
      _ => (null, null),
    };
    if (label == null || route == null) return const SizedBox.shrink();
    return SizedBox(
      height: kBoardToolbarControlHeight,
      child: FilledButton.icon(
        onPressed: () => openTicketEditor(ref, route),
        icon: Icon(PhosphorIconsLight.plus, size: context.spacing.xl3),
        label: Text(label),
      ),
    );
  }
}
