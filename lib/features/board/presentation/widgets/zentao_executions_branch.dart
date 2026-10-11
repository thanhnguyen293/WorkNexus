import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';
import 'sidebar_tree_rows.dart';
import 'zentao_execution_row.dart';

/// The Tasks tree under a ZenTao node: a collapsible "Tasks" group (collapsed by
/// default) whose children are the account's projects, each expanding to the
/// executions that hold the task board's tasks. Pinned executions are lifted out
/// into the per-account Pinned area ([ZenTaoPinnedBranch]).
class ZenTaoExecutionsBranch extends ConsumerWidget {
  const ZenTaoExecutionsBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      zentaoExecutionsExpandedProvider.select((s) => s.contains(account.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarGroupToggle(
          label: l.tasks,
          expanded: expanded,
          onTap: () => ref
              .read(zentaoExecutionsExpandedProvider.notifier)
              .toggle(account.id),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: _Projects(account: account, tickets: tickets),
          ),
      ],
    );
  }
}

class _Projects extends ConsumerWidget {
  const _Projects({required this.account, required this.tickets});

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final projects = ref.watch(zentaoProjectsProvider(account.id));

    return projects.when(
      data: (items) {
        if (items.isEmpty) return SidebarStatusRow(label: l.noExecutions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in items)
              _ProjectNode(accountId: account.id, project: p, tickets: tickets),
          ],
        );
      },
      loading: () =>
          SidebarStatusRow(label: l.loadingExecutions, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.executionsUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(zentaoProjectsProvider(account.id)),
      ),
    );
  }
}

class _ProjectNode extends ConsumerWidget {
  const _ProjectNode({
    required this.accountId,
    required this.project,
    required this.tickets,
  });

  final String accountId;
  final ProviderProject project;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '$accountId:${project.id}';
    final expanded = ref.watch(
      zentaoExecutionProjectsExpandedProvider.select((s) => s.contains(key)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarGroupToggle(
          label: project.name,
          expanded: expanded,
          onTap: () => ref
              .read(zentaoExecutionProjectsExpandedProvider.notifier)
              .toggle(key),
          icon: LucideIcons.folder300,
          labelStyle: context.typography.mono.copyWith(
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: _Executions(
              accountId: accountId,
              projectId: project.id,
              tickets: tickets,
            ),
          ),
      ],
    );
  }
}

class _Executions extends ConsumerWidget {
  const _Executions({
    required this.accountId,
    required this.projectId,
    required this.tickets,
  });

  final String accountId;
  final String projectId;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final executions = ref.watch(
      zentaoExecutionsProvider((accountId: accountId, projectId: projectId)),
    );
    final pinnedKeys = {
      for (final e in ref.watch(
        appSettingsProvider.select((s) => s.pinnedExecutions),
      ))
        e.key,
    };

    return executions.when(
      data: (items) {
        if (items.isEmpty) return SidebarStatusRow(label: l.noExecutions);
        // Pinned executions surface in the Pinned area, so drop them here.
        final rest = [
          for (final e in items)
            if (!pinnedKeys.contains('${e.accountId}:${e.id}')) e,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in rest)
              ZenTaoExecutionRow(execution: e, tickets: tickets, pinned: false),
          ],
        );
      },
      loading: () =>
          SidebarStatusRow(label: l.loadingExecutions, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.executionsUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(
          zentaoExecutionsProvider((
            accountId: accountId,
            projectId: projectId,
          )),
        ),
      ),
    );
  }
}
