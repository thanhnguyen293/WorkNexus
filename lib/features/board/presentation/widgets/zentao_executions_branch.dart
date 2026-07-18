import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';
import 'zentao_execution_row.dart';

/// The Executions tree under a ZenTao node: a collapsible "Executions" group
/// (collapsed by default) whose children are the account's projects, each
/// expanding to the executions that hold the task board's tasks.
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
    final c = context.colors;
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      zentaoExecutionsExpandedProvider.select((s) => s.contains(account.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => ref
              .read(zentaoExecutionsExpandedProvider.notifier)
              .toggle(account.id),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: 27,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: c.textTertiary,
                ),
                SizedBox(width: context.spacing.xs),
                Expanded(
                  child: Text(
                    l.executions,
                    style: context.typography.mono.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        if (items.isEmpty) return _MutedRow(label: l.noExecutions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in items)
              _ProjectNode(accountId: account.id, project: p, tickets: tickets),
          ],
        );
      },
      loading: () => _MutedRow(label: l.loadingExecutions),
      error: (_, _) => _MutedRow(label: l.executionsUnavailable),
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
    final c = context.colors;
    final key = '$accountId:${project.id}';
    final expanded = ref.watch(
      zentaoExecutionProjectsExpandedProvider.select((s) => s.contains(key)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => ref
              .read(zentaoExecutionProjectsExpandedProvider.notifier)
              .toggle(key),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: 27,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: c.textTertiary,
                ),
                SizedBox(width: context.spacing.xs),
                Icon(Icons.folder_outlined, size: 13, color: c.textTertiary),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.mono.copyWith(
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
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

    return executions.when(
      data: (items) {
        if (items.isEmpty) return _MutedRow(label: l.noExecutions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in items)
              ZenTaoExecutionRow(execution: e, tickets: tickets),
          ],
        );
      },
      loading: () => _MutedRow(label: l.loadingExecutions),
      error: (_, _) => _MutedRow(label: l.executionsUnavailable),
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 27,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
