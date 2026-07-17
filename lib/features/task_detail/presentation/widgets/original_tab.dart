import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import 'section_label.dart';

/// The "Original" tab — the ticket's source description + metadata table.
class OriginalTab extends ConsumerWidget {
  const OriginalTab({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final meta = <(String, String)>[
      (l.project, lookups.projects[ticket.projectId]?.name ?? ''),
      (l.account, account?.handle ?? ''),
      (l.workspace, ws?.isPersonal == true ? l.personal : (ws?.name ?? '')),
      (l.status, statusLabel(l, ticket.status)),
      (
        l.priority,
        priorityLabel(
          ticket.providerType,
          ticket.priority,
        ).replaceAll('◆ ', ''),
      ),
      (l.updated, formatWhen(context, ticket.updatedAt)),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl3,
        context.spacing.xl3,
        context.spacing.xl3,
        context.spacing.xl4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l.description),
          SizedBox(height: context.spacing.md),
          MarkdownText(
            ticket.body,
            imageLoader: (url) =>
                ref.read(syncServiceProvider).fetchTicketImage(ticket, url),
          ),
          if (ticket.labels.isNotEmpty) ...[
            SizedBox(height: context.spacing.xs),
            Wrap(
              spacing: context.spacing.xs,
              runSpacing: context.spacing.xs,
              children: [
                for (final lb in ticket.labels)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.md,
                      vertical: context.spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceSubtle,
                      borderRadius: BorderRadius.circular(context.radii.xl),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      lb,
                      style: context.typography.monoSm.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (ticket.providerEntity != null) ...[
            SizedBox(height: context.spacing.xl3),
            ZenTaoDetailsSection(entity: ticket.providerEntity!),
          ],
          SizedBox(height: context.spacing.xl3),
          Container(height: 1, color: c.border),
          SizedBox(height: context.spacing.xs),
          for (final m in meta)
            Container(
              padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      m.$1,
                      style: context.typography.meta.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      m.$2,
                      style: context.typography.secondary.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ZenTaoDetailsSection extends StatelessWidget {
  const ZenTaoDetailsSection({super.key, required this.entity});

  final TicketProviderEntity entity;

  @override
  Widget build(BuildContext context) {
    return switch (entity) {
      final ZenTaoBugEntity bug => ZenTaoBugDetails(bug),
    };
  }
}

class ZenTaoBugDetails extends StatelessWidget {
  const ZenTaoBugDetails(this.bug, {super.key});

  final ZenTaoBugEntity bug;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Product', _joined([bug.productName, bug.product])),
      ('Project', _joined([bug.projectName, bug.project])),
      ('Execution', _joined([bug.executionName, bug.execution])),
      ('Plan', _joined([bug.planName, bug.plan])),
      ('Story', _joined([bug.storyTitle, bug.story])),
      ('Task', _joined([bug.taskName, bug.task])),
      ('Branch', bug.branch ?? ''),
      ('Module', bug.module ?? ''),
      ('Type', bug.bugType ?? ''),
      ('Severity', bug.severity?.toString() ?? ''),
      ('Confirmed', _confirmedLabel(bug.confirmed)),
      ('Resolution', bug.resolution ?? ''),
      ('OS', bug.os ?? ''),
      ('Browser', bug.browser ?? ''),
      ('Opened by', bug.openedBy ?? ''),
      ('Opened', formatWhen(context, bug.openedDate)),
      ('Opened build', bug.openedBuild ?? ''),
      ('Assigned to', bug.assignedTo ?? ''),
      ('Assigned', formatWhen(context, bug.assignedDate)),
      ('Deadline', bug.deadline ?? ''),
      ('Resolved by', bug.resolvedBy ?? ''),
      ('Resolved', formatWhen(context, bug.resolvedDate)),
      ('Resolved build', bug.resolvedBuild ?? ''),
      ('Closed by', bug.closedBy ?? ''),
      ('Closed', formatWhen(context, bug.closedDate)),
      ('Last edited by', bug.lastEditedBy ?? ''),
      ('Last edited', formatWhen(context, bug.lastEditedDate)),
    ].where((row) => row.$2.trim().isNotEmpty).toList();

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('ZenTao details'),
        SizedBox(height: context.spacing.xs),
        DetailRows(rows: rows),
      ],
    );
  }

  String _confirmedLabel(int? value) => switch (value) {
    0 => 'Unconfirmed',
    1 => 'Confirmed',
    _ => '',
  };

  String _joined(List<String?> values) {
    final cleaned = values
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    return cleaned.join(' · ');
  }
}

class DetailRows extends StatelessWidget {
  const DetailRows({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final row in rows)
          Container(
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    row.$1,
                    style: context.typography.meta.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: context.typography.secondary.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
