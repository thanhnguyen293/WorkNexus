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
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/label_chips.dart';
import '../../../translation/presentation/translation_providers.dart';
import '../board_providers.dart';
import 'ticket_card_meta.dart';

/// A board card rendering one ticket, matching the editorial design.
class TicketCard extends ConsumerWidget {
  const TicketCard(this.ticket, {super.key});
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
    final cardLabels = visibleUserLabels(ticket.labels);
    final labelColors = labelColorsOf(ticket);

    final stripeWidth = selected ? 5.0 : 4.0;
    final bg = selected
        ? c.mix(c.card, wsColor, 0.16)
        : c.tintedCard(wsColor, enabled: tint);
    final side = context.borders.showOutline
        ? context.hairlineSide
        : BorderSide.none;

    return Opacity(
      opacity: pending ? 0.48 : 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: pending
              ? null
              : () => ref.read(openTicketIdProvider.notifier).open(ticket.id),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.card),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                border: Border(top: side, right: side, bottom: side),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: stripeWidth, color: wsColor),
                    Expanded(
                      child: Padding(
                        padding: context.spacing.cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  ticketRef(
                                    ticket.providerType,
                                    ticket.externalKey,
                                    ticket.externalType,
                                  ),
                                  style: context.typography.mono.copyWith(
                                    color: c.textTertiary,
                                  ),
                                ),
                                SizedBox(width: context.spacing.sm),
                                const Spacer(),

                                if (ticket.severity != null)
                                  SeverityTag(ticket.severity!),
                                SizedBox(width: context.spacing.sm),
                                PriorityTag(
                                  ticket.providerType,
                                  ticket.priority,
                                ),
                              ],
                            ),
                            SizedBox(height: context.spacing.md),
                            Text(
                              ticket.title,
                              style: context.typography.cardTitle.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                            if (cardLabels.isNotEmpty) ...[
                              SizedBox(height: context.spacing.md),
                              LabelChips(
                                labels: cardLabels,
                                colors: labelColors.background,
                                textColors: labelColors.text,
                              ),
                            ],
                            SizedBox(height: context.spacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AssigneeChip(ticket.assignee, wsColor),
                                ),
                                SizedBox(width: context.spacing.sm),
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
        ),
      ),
    );
  }
}
