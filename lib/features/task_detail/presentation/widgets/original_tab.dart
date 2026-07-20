import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/label_chips.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../util/image_fallback.dart';
import 'bug_attachments.dart';
import 'bug_description.dart';
import 'bug_detail_sections.dart';
import 'bug_people_row.dart';
import 'bug_status_strip.dart';
import 'detail_field_rows.dart';
import 'detail_scroll_body.dart';
import 'provider_detail_sections.dart';
import 'section_label.dart';

/// The "Original" tab — the ticket's source description plus typed metadata.
///
/// For a ZenTao bug it surfaces the full payload: an at-a-glance status strip,
/// the people involved, the description (steps to reproduce), attachments, and
/// grouped classification/lifecycle details. Non-ZenTao tickets fall back to the
/// generic description + meta table.
class OriginalTab extends ConsumerWidget {
  const OriginalTab({super.key, required this.ticket, required this.layout});
  final Ticket ticket;
  final DetailLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final imageFallback = ImageFallback.forTicket(ticket, account);
    final bug = switch (ticket.providerEntity) {
      final ZenTaoBugEntity b => b,
      _ => null,
    };
    final gitlab = switch (ticket.providerEntity) {
      final GitLabItemEntity e => e,
      _ => null,
    };
    final github = switch (ticket.providerEntity) {
      final GitHubItemEntity e => e,
      _ => null,
    };
    final labels = visibleUserLabels(ticket.labels);
    final labelColors = labelColorsOf(ticket);
    final meta = <(String, String)>[
      (l.project, lookups.projects[ticket.projectId]?.name ?? ''),
      (l.account, account?.handle ?? ''),
      (l.workspace, ws?.isPersonal == true ? l.personal : (ws?.name ?? '')),
      (l.status, statusLabel(l, ticket.status)),
      if (hasExplicitPriority(ticket))
        (
          l.priority,
          priorityLabel(
            ticket.providerType,
            ticket.priority,
          ).replaceAll('◆ ', ''),
        ),
      (
        l.updated,
        formatWhen(
          context,
          ticket.updatedAt,
          format: ref.watch(appSettingsProvider.select((s) => s.dateFormat)),
        ),
      ),
    ];

    // The description, people and attachments — the narrative of the bug.
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bug != null) ...[
          BugStatusStrip(ticket: ticket, bug: bug),
          SizedBox(height: context.spacing.xl2),
          BugPeopleRow(bug: bug),
          SizedBox(height: context.spacing.xl3),
        ],
        SectionLabel(l.description),
        SizedBox(height: context.spacing.md),
        if (bug != null)
          BugDescription(
            body: ticket.body,
            imageLoader: (url) =>
                getIt<SyncService>().fetchTicketImage(ticket, url),
            imageFallback: imageFallback,
          )
        else
          MarkdownText(
            ticket.body,
            imageLoader: (url) =>
                getIt<SyncService>().fetchTicketImage(ticket, url),
            imageFallbackUrl: imageFallback.resolveUrl,
            onOpenImage: imageFallback.open,
          ),
        if (labels.isNotEmpty) ...[
          SizedBox(height: context.spacing.xl2),
          SectionLabel(l.labels),
          SizedBox(height: context.spacing.md),
          LabelChips(
            labels: labels,
            colors: labelColors.background,
            textColors: labelColors.text,
          ),
        ],
        if (bug != null && bug.attachments.isNotEmpty) ...[
          SizedBox(height: context.spacing.xl3),
          BugAttachments(ticket: ticket, attachments: bug.attachments),
        ],
      ],
    );

    // The typed metadata — a sidebar in two-pane, stacked below in document.
    // A ZenTao bug shows its classification/lifecycle card; other providers
    // fall back to the generic key/value table.
    final Widget sidebar;
    if (bug != null) {
      sidebar = ZenTaoBugSections(bug);
    } else if (gitlab != null) {
      sidebar = GitLabDetailSections(ticket: ticket, entity: gitlab);
    } else if (github != null) {
      sidebar = GitHubDetailSections(ticket: ticket, entity: github);
    } else {
      sidebar = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: c.border),
          SizedBox(height: context.spacing.xs),
          DetailFieldRows(rows: meta, labelWidth: 96),
        ],
      );
    }

    return DetailScrollBody(layout: layout, content: content, sidebar: sidebar);
  }
}
