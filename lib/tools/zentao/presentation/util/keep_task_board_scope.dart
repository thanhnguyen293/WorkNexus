import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/pinned_execution.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';

/// Keeps the Tasks board on a place of [account]: ZenTao lists tasks per
/// execution only, so there is no account-wide board. The scope the user
/// picked when it is still there; otherwise — first open, the project gone,
/// another account — a pinned execution (paged), else a pinned project, else
/// the first project (their cached tasks). Only while the section is on
/// screen (the viewport keeps a few alive).
void keepTaskBoardScope(
  BuildContext context,
  WidgetRef ref,
  Account account,
  ToolLocation location,
) {
  final projects = ref.watch(zentaoProjectsProvider(account.id)).asData?.value;
  if (projects == null ||
      projects.isEmpty ||
      !TickerMode.valuesOf(context).enabled) {
    return;
  }
  final scope = location.scopeId;
  final execution = ref.read(selectedZenTaoExecutionProvider);
  final onExecution =
      execution?.accountId == account.id && execution?.executionId == scope;
  if (scope != null && (onExecution || projects.any((p) => p.id == scope))) {
    return;
  }

  final settings = ref.read(appSettingsProvider);
  final pinnedExecution = settings.pinnedExecutions
      .where((e) => e.accountId == account.id)
      .firstOrNull;
  final ProviderProject project = projects.firstWhere(
    (p) =>
        settings.pinnedProjects.contains(zentaoProjectPinKey(account.id, p.id)),
    orElse: () => projects.first,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final nav = ref.read(appNavProvider.notifier);
    if (pinnedExecution != null) {
      nav.selectScope(pinnedExecution.executionId);
      ref
          .read(selectedZenTaoExecutionProvider.notifier)
          .select(
            ProviderExecution(
              id: pinnedExecution.executionId,
              name: pinnedExecution.name,
              projectId: pinnedExecution.projectId,
              accountId: account.id,
            ),
          );
    } else {
      nav.selectScope(project.id);
      ref.read(selectedZenTaoExecutionProvider.notifier).clear();
    }
    ref
        .read(filterStateProvider.notifier)
        .openBoard(ref.read(boardKeyProvider));
  });
}
