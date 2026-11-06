import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../features/translation/presentation/translation_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/board/presentation/widgets/ticket_card_meta.dart';
import 'zentao_card_parent.dart';
import 'zentao_formatters.dart';

/// A ZenTao bug's or task's card on its board, kept to what triage needs: the
/// id, severity (bugs), priority and how long ago it changed; a subtask's
/// parent; the title without the bracketed tags ZenTao titles start with
/// ("[Discovery]"); how late an overdue task is; the assignee. No workspace
/// stripe: a ZenTao board shows one product or execution of one account.
class ZenTaoBoardCard extends ConsumerWidget {
  const ZenTaoBoardCard(this.ticket, {super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final wsColorValue = ref.watch(
      lookupsProvider.select((l) {
        final account = l.accounts[ticket.accountId];
        return account == null
            ? null
            : l.workspaces[account.workspaceId]?.colorValue;
      }),
    );
    final wsColor = wsColorValue == null
        ? c.workspaceFallback
        : Color(wsColorValue);
    final tint = ref.watch(appSettingsProvider.select((s) => s.companyTint));
    final selected = ref.watch(
      openTicketIdProvider.select((id) => id == ticket.id),
    );
    final pending = ref.watch(
      ticketActionPendingProvider.select((ids) => ids.contains(ticket.id)),
    );
    final trStatus = ref.watch(
      translationStatusProvider(ticket.id).select((t) => t.state),
    );
    final (title, _) = ZenTaoFormatters.extractTags(ticket.title);
    final border = context.borders.showOutline
        ? Border.all(color: c.border)
        : null;

    return Opacity(
      opacity: pending ? 0.48 : 1,
      child: HoverSurface(
        onTap: pending
            ? null
            : () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
        selected: selected,
        color: selected
            ? c.mix(c.card, wsColor, 0.16)
            : c.tintedCard(wsColor, enabled: tint),
        borderRadius: BorderRadius.circular(context.radii.card),
        border: selected ? Border.all(color: c.accent) : border,
        hoverBorder: border == null ? null : Border.all(color: c.borderStrong),
        padding: s.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: s.sm,
          children: [
            _TopLine(ticket),
            if (ticket.providerEntity case ZenTaoTaskEntity(
              :final parentId?,
              :final parentName,
            ))
              ZenTaoCardParent(
                accountId: ticket.accountId,
                parentId: parentId,
                parentName: parentName,
              ),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.typography.cardTitle.copyWith(
                color: c.textPrimary,
              ),
            ),
            ?switch (ZenTaoFormatters.calcDelayText(
              ZenTaoFormatters.extractDeadline(ticket),
            )) {
              final late? => _DelayTag(late),
              null => null,
            },
            Row(
              spacing: s.sm,
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
    );
  }
}

/// "#7265", severity, priority, and how long ago the bug changed.
class _TopLine extends StatelessWidget {
  const _TopLine(this.ticket);

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final severity = ticket.severity;
    final age = _age(AppL10n.of(context), ticket.updatedAt);
    return Row(
      spacing: context.spacing.sm,
      children: [
        Text(
          '#${ticket.externalKey}',
          style: context.typography.mono.copyWith(color: c.textTertiary),
        ),
        ?switch (severity) {
          final severity? => SeverityTag(severity),
          null => null,
        },
        if (hasExplicitPriority(ticket))
          PriorityTag(ticket.providerType, ticket.priority),
        const Spacer(),
        if (age != null)
          Text(
            age,
            style: context.typography.monoXs.copyWith(color: c.textTertiary),
          ),
      ],
    );
  }

  /// "5m ago", "3h ago", "2d ago"; nothing without a time.
  static String? _age(AppL10n l, DateTime? at) {
    if (at == null) return null;
    final d = DateTime.now().difference(at);
    if (d.inHours < 1) return l.minutesAgo(d.inMinutes < 1 ? 1 : d.inMinutes);
    if (d.inDays < 1) return l.hoursAgo(d.inHours);
    return l.daysAgo(d.inDays);
  }
}

/// How late an overdue task is, in the error colour.
class _DelayTag extends StatelessWidget {
  const _DelayTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(c.error, 0.12),
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(
        text,
        style: context.typography.monoXs.copyWith(
          color: c.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
