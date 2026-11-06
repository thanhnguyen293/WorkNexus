import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/pinned_execution.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../providers/zentao_board_providers.dart';
import '../util/open_execution_board.dart';
import '../widgets/zentao_execution_popover.dart';
import 'zentao_module_tree_section.dart';
import 'zentao_scope_picker_row.dart';

/// The Tasks side panel, like the Bugs one: the pinned executions (and the
/// open one), a picker for any other, then the execution's module tree,
/// which narrows the board.
class ZentaoTaskModulePane extends ConsumerWidget {
  const ZentaoTaskModulePane({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final open = ref.watch(selectedZenTaoExecutionProvider);
    final current = switch (open) {
      final o? when o.accountId == account.id => PinnedExecution(
        accountId: o.accountId,
        projectId: o.projectId,
        executionId: o.executionId,
        name: o.executionName,
      ),
      _ => null,
    };
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedExecutions),
    );
    bool isPinned(PinnedExecution e) => pinned.any((p) => p.key == e.key);
    // The pinned ones in their own order, so opening one never reorders
    // them; an open execution that is not pinned shows above them.
    final rows = [
      if (current != null && !isPinned(current)) current,
      for (final e in pinned)
        if (e.accountId == account.id) e,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(s.sm, s.xs, s.sm, s.lg),
            children: [
              ScopeGroupHeader(title: l.executions),
              for (final e in rows)
                ScopeRow(
                  name: e.name,
                  icon: LucideIcons.zap300,
                  selected: e.key == current?.key,
                  isPinned: isPinned(e),
                  onPinToggle: () => ref
                      .read(appSettingsProvider.notifier)
                      .togglePinnedExecution(e),
                  onTap: () => openExecutionBoard(
                    context,
                    ref,
                    ProviderExecution(
                      id: e.executionId,
                      name: e.name,
                      projectId: e.projectId,
                      accountId: e.accountId,
                    ),
                  ),
                ),
              ZenTaoScopePickerRow(
                label: l.zentaoOtherExecutions,
                popover: (close) =>
                    ZenTaoExecutionPopover(account: account, onClose: close),
              ),
              SizedBox(height: s.sm),
              const ZenTaoModuleTreeSection(bugs: false),
            ],
          ),
        ),
        const ZenTaoHideEmptyModulesToggle(),
      ],
    );
  }
}
