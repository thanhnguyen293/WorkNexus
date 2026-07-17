import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
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
