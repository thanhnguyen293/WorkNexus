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
import 'zentao_formatters.dart';
import 'zentao_priority_badge.dart';

/// Dedicated Kanban card for ZenTao Tasks, tailored to the ZenTao workflow:
/// high-density layout, circular priority indicator (①, ②, ③, ④), module chip,
/// soft-red Delay badge for overdue items, and assignee photo/initial.
class ZenTaoTaskCard extends ConsumerWidget {
  const ZenTaoTaskCard(this.ticket, {super.key});

  final Ticket ticket;

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
                        // Top row: ID, Module Tag, Priority Circle
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
                                '#${ticket.externalKey}',
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
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            ZenTaoPriorityBadge(
                              priority: ticket.priority,
                              size: 22,
                            ),
                          ],
                        ),
                        SizedBox(height: context.spacing.sm),

                        // Title
                        Text(
                          cleanTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.cardTitle.copyWith(
                            color: c.textPrimary,
                            height: 1.35,
                          ),
                        ),

                        // Delay Warning Badge if overdue
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
                              border: Border.all(
                                color: c.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 13,
                                  color: c.error,
                                ),
                                SizedBox(width: context.spacing.xs),
                                Text(
                                  delayText,
                                  style: context.typography.monoXs.copyWith(
                                    color: c.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: context.spacing.md),

                        // Footer row: Assignee, Deadline, Translation status
                        Row(
                          children: [
                            if (ticket.assignee?.isNotEmpty == true) ...[
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: c.selectionFill,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  ticket.assignee![0].toUpperCase(),
                                  style: context.typography.monoXs.copyWith(
                                    color: c.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: context.spacing.xs),
                              Text(
                                ticket.assignee!,
                                style: context.typography.bodySm.copyWith(
                                  color: c.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Unassigned',
                                style: context.typography.bodySm.copyWith(
                                  color: c.textTertiary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (deadline != null) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: delayText != null
                                    ? c.error
                                    : c.textTertiary,
                              ),
                              SizedBox(width: context.spacing.xxs),
                              Text(
                                ZenTaoFormatters.formatDeadline(deadline),
                                style: context.typography.monoXs.copyWith(
                                  color: delayText != null
                                      ? c.error
                                      : c.textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                              SizedBox(width: context.spacing.sm),
                            ],
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
