import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../../../core/util/body_format.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/label_chips.dart';
import '../../../../core/widgets/rich_body_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/image_fallback.dart';
import 'comments_section.dart';
import 'detail_scroll_body.dart';
import 'detail_section_title.dart';
import 'provider_detail_sections.dart';
import 'section_label.dart';
import 'ticket_status_pill.dart';

/// The "Original" tab — the ticket's source description plus typed metadata.
///
/// Surfaces provider-specific widgets (effort, subtasks, attachments, custom
/// sidebar) via [ToolModule] hooks, falling back to standard description +
/// metadata card.
class OriginalTab extends ConsumerWidget {
  const OriginalTab({super.key, required this.ticket, required this.layout});
  final Ticket ticket;
  final DetailLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final imageFallback = ImageFallback.forTicket(ticket, account);
    final html = isHtmlBody(ticket.providerType, ticket.body);
    final tool = ref.watch(toolRegistryProvider)[ticket.providerType];

    final isBug = ticket.providerEntity is ZenTaoBugEntity;
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

    final effortWidget = tool?.buildDetailEffort(context, ticket);
    final subtasksWidget = tool?.buildDetailSubtasks(context, ticket);
    final attachmentsWidget = tool?.buildDetailAttachments(context, ticket);

    final prose = context.typography.prose;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (effortWidget != null) ...[
          effortWidget,
          SizedBox(height: context.spacing.xl3),
        ],
        DetailSectionTitle(isBug ? l.fieldSteps : l.description),
        SelectionArea(
          child: RichBodyText(
            ticket.body,
            html: html,
            fontSize: prose.fontSize ?? 14,
            height: prose.height ?? 1.6,
            imageLoader: (url) =>
                getIt<TicketDetailService>().fetchTicketImage(ticket, url),
            imageFallbackUrl: imageFallback.resolveUrl,
            onOpenImage: imageFallback.open,
          ),
        ),
        if (subtasksWidget != null) ...[
          SizedBox(height: context.spacing.xl2),
          subtasksWidget,
        ],
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
        if (attachmentsWidget != null) ...[
          SizedBox(height: context.spacing.xl3),
          attachmentsWidget,
        ],
      ],
    );

    final activity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSectionTitle('${l.comments} & ${l.activity}'),
        CommentsSection(ticket: ticket, imageFallback: imageFallback),
      ],
    );

    final sidebar =
        tool?.buildDetailSidebar(context, ticket) ??
        DetailMetaCard(
          title: l.details,
          rows: meta,
          valueWidgets: {l.status: TicketStatusPill(ticket: ticket)},
        );

    return DetailScrollBody(
      layout: layout,
      content: content,
      sidebar: sidebar,
      activity: activity,
    );
  }
}
