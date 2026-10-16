import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';

/// Whether the Tasks board of [account] at [location] has its execution:
/// ZenTao lists tasks per execution only, so that is the one place a task
/// board can be.
bool taskBoardHasExecution(
  WidgetRef ref,
  Account account,
  ToolLocation location,
) {
  final execution = ref.watch(selectedZenTaoExecutionProvider);
  return location.scopeId != null &&
      execution?.accountId == account.id &&
      execution?.executionId == location.scopeId;
}

/// Keeps the Tasks board of [account] on an execution, as the old board was
/// (it only opened on one): the one picked while it still is; else a pinned
/// execution of the account (the scope's own when it is pinned); else the
/// first execution of the first project, loaded on demand. With none of
/// those the section asks the user to pick one. Never a project: it holds
/// executions, not a task list. Only while the section is on screen (the
/// viewport keeps a few alive).
void keepTaskBoardScope(
  BuildContext context,
  WidgetRef ref,
  Account account,
  ToolLocation location,
) {
  if (!TickerMode.valuesOf(context).enabled) return;
  if (taskBoardHasExecution(ref, account, location)) return;

  final pinned = ref
      .read(appSettingsProvider)
      .pinnedExecutions
      .where((e) => e.accountId == account.id)
      .toList();
  final ProviderExecution pick;
  if (pinned.isNotEmpty) {
    final e =
        pinned.where((e) => e.executionId == location.scopeId).firstOrNull ??
        pinned.first;
    pick = ProviderExecution(
      id: e.executionId,
      name: e.name,
      projectId: e.projectId,
      accountId: account.id,
    );
  } else {
    final first = ref
        .watch(zentaoProjectsProvider(account.id))
        .asData
        ?.value
        .firstOrNull;
    if (first == null) return;
    final executions = ref
        .watch(
          zentaoExecutionsProvider((
            accountId: account.id,
            projectId: first.id,
          )),
        )
        .asData
        ?.value;
    final execution = executions?.firstOrNull;
    if (execution == null) return;
    pick = execution;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ref.read(appNavProvider.notifier).selectScope(pick.id);
    ref.read(selectedZenTaoExecutionProvider.notifier).select(pick);
    ref
        .read(filterStateProvider.notifier)
        .openBoard(ref.read(boardKeyProvider));
  });
}
