import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../detail_providers.dart';
import '../ticket_actions.dart';
import 'detail_header_icon_button.dart';
import 'parent_task_link.dart';

/// The detail panel header: workspace + provider identity, title, actions.
class DetailHeader extends ConsumerWidget {
  const DetailHeader({
    super.key,
    required this.ticket,
    required this.wsColor,
    required this.onClose,
  });
  final Ticket ticket;
  final Color wsColor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final l = AppL10n.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl3,
        context.spacing.xl2,
        context.spacing.xl3,
        context.spacing.xl,
      ),
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WorkspaceBadge(
                wsColor,
                ws?.shortCode ?? '?',
                big: true,
                iconKey: ws?.iconKey,
              ),
              SizedBox(width: context.spacing.md),
              Text(
                ws?.isPersonal == true ? l.personal : (ws?.name ?? ''),
                style: context.typography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: wsColor,
                ),
              ),
              const Spacer(),
              if (_editRoute(ticket) case final route?) ...[
                DetailHeaderIconButton(
                  icon: PhosphorIconsLight.pencilSimple,
                  tooltip: l.edit,
                  onTap: () {
                    // The editor takes the screen; the detail reopens on save.
                    ref.read(openTicketIdProvider.notifier).close();
                    ref.read(ticketEditorProvider.notifier).open(route);
                  },
                ),
                SizedBox(width: context.spacing.md),
              ],
              DetailHeaderIconButton(
                icon: PhosphorIconsLight.arrowsClockwise,
                tooltip: l.refresh,
                onTap: () =>
                    ref.invalidate(ticketDetailSyncProvider(ticket.id)),
              ),
              SizedBox(width: context.spacing.md),
              if (ticket.url != null && ticket.url!.isNotEmpty) ...[
                DetailHeaderCopyLinkButton(url: ticket.url!),
                SizedBox(width: context.spacing.md),
                DetailHeaderIconButton(
                  icon: PhosphorIconsLight.arrowSquareOut,
                  tooltip: l.openInBrowser,
                  onTap: () => openExternally(ticket.url!),
                ),
                SizedBox(width: context.spacing.md),
              ],
              DetailHeaderIconButton(
                icon: PhosphorIconsLight.x,
                tooltip: l.close,
                onTap: onClose,
              ),
            ],
          ),
          SizedBox(height: context.spacing.lg),
          Row(
            children: [
              Text(
                ticketRef(
                  ticket.providerType,
                  ticket.externalKey,
                  ticket.externalType,
                ),
                style: context.typography.mono.copyWith(color: c.textSecondary),
              ),
              if (hasExplicitPriority(ticket)) ...[
                SizedBox(width: context.spacing.sm),
                PriorityTag(ticket.providerType, ticket.priority),
              ],
              if (ticket.severity != null) ...[
                SizedBox(width: context.spacing.sm),
                SeverityTag(ticket.severity),
              ],
            ],
          ),
          // A subtask names its parent right above its own title.
          if (ticket.providerEntity case ZenTaoTaskEntity(
            :final parentId?,
            :final parentName,
          )) ...[
            SizedBox(height: context.spacing.md),
            ParentTaskLink(
              ticket: ticket,
              parentId: parentId,
              parentName: parentName,
            ),
          ],
          SizedBox(height: context.spacing.md),
          Text(
            ticket.title,
            style: context.typography.detailTitle.copyWith(
              color: c.textPrimary,
            ),
          ),
          TicketActionsBar(ticket: ticket),
        ],
      ),
    );
  }
}

/// The editor for a ZenTao bug or task; null for anything else.
TicketEditorRoute? _editRoute(Ticket ticket) {
  if (ticket.providerType != ProviderType.zentao) return null;
  return switch (ticket.externalType?.toLowerCase()) {
    'bug' => EditBugRoute(
      accountId: ticket.accountId,
      bugId: ticket.externalKey,
      ticketId: ticket.id,
    ),
    'task' => EditTaskRoute(
      accountId: ticket.accountId,
      taskId: ticket.externalKey,
      ticketId: ticket.id,
    ),
    _ => null,
  };
}
