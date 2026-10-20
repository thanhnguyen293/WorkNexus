import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../features/translation/presentation/translation_providers.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/board/presentation/widgets/ticket_card_meta.dart';
import 'zentao_formatters.dart';

/// The Kanban card of a ZenTao bug or task, one look for both: its [kind]
/// and id with its module, a [badge] for how much it matters (a bug's
/// severity, a task's priority), the title, a delay badge when it is overdue,
/// and its assignee.
class ZenTaoTicketCard extends ConsumerWidget {
  const ZenTaoTicketCard(
    this.ticket, {
    super.key,
    required this.kind,
    this.badge,
  });

  final Ticket ticket;

  /// "Bug" or "Task", before the id.
  final String kind;
  final Widget? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final wsColor = ws == null ? c.workspaceFallback : Color(ws.colorValue);
    final tint = ref.watch(appSettingsProvider).companyTint;
    final selected = ref.watch(openTicketIdProvider) == ticket.id;
    final pending = ref.watch(
      ticketActionPendingProvider.select((ids) => ids.contains(ticket.id)),
    );
    final trStatus = ref.watch(translationStatusProvider(ticket.id)).state;

    final bg = selected
        ? c.mix(c.card, wsColor, 0.16)
        : c.tintedCard(wsColor, enabled: tint);
    final border = context.borders.showOutline
        ? Border.all(color: c.border)
        : null;

    final deadline = ZenTaoFormatters.extractDeadline(ticket);
    final delayText = ZenTaoFormatters.calcDelayText(deadline);
    final (cleanTitle, moduleTag) = ZenTaoFormatters.extractModule(
      ticket.title,
    );

    return Opacity(
      opacity: pending ? 0.48 : 1,
      child: HoverSurface(
        onTap: pending
            ? null
            : () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
        color: bg,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: border,
        hoverBorder: border == null ? null : Border.all(color: c.borderStrong),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.card),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: selected ? 5.0 : 4.0, color: wsColor),
                Expanded(
                  child: Padding(
                    padding: context.spacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.spacing.sm,
                                vertical: context.spacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: c.surfaceSubtle,
                                borderRadius: BorderRadius.circular(
                                  context.radii.xs,
                                ),
                              ),
                              child: Text(
                                '$kind #${ticket.externalKey}',
                                style: context.typography.mono.copyWith(
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (moduleTag != null) ...[
                              SizedBox(width: context.spacing.xs),
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.xs,
                                    vertical: context.spacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.selectionFill,
                                    borderRadius: BorderRadius.circular(
                                      context.radii.xs,
                                    ),
                                  ),
                                  child: Text(
                                    moduleTag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.typography.monoXs.copyWith(
                                      color: c.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            ?badge,
                          ],
                        ),
                        SizedBox(height: context.spacing.sm),

                        Text(
                          cleanTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.cardTitle.copyWith(
                            color: c.textPrimary,
                            height: 1.35,
                          ),
                        ),

                        if (delayText != null) ...[
                          SizedBox(height: context.spacing.sm),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacing.sm,
                              vertical: context.spacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: c.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                context.radii.xs,
                              ),
                            ),
                            child: Text(
                              delayText,
                              style: context.typography.monoXs.copyWith(
                                color: c.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: context.spacing.md),

                        Row(
                          children: [
                            Expanded(
                              child: AssigneeChip(
                                ticket.assignee,
                                wsColor,
                                accountId: ticket.accountId,
                              ),
                            ),
                            TranslationDot(trStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
