import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/agent_session.dart';
import '../../../../core/domain/entities/dev_link.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/translation_state.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/widgets/badges.dart';
import '../../../agents/presentation/agent_providers.dart';
import '../../../task_detail/presentation/detail_providers.dart';
import '../../../translation/presentation/translation_providers.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/usecases/derive_dev_context.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
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
    final projectName = lookups.projects[ticket.projectId]?.name ?? '';
    final tint = ref.watch(appSettingsProvider).companyTint;
    final selected = ref.watch(openTicketIdProvider) == ticket.id;
    final pending = ref.watch(
      ticketActionPendingProvider.select((ids) => ids.contains(ticket.id)),
    );

    final trStatus = ref.watch(translationStatusProvider(ticket.id)).state;
    final links =
        ref.watch(devLinksProvider(ticket.id)).asData?.value ??
        const <DevLink>[];
    final sessions =
        ref.watch(agentSessionsProvider(ticket.id)).asData?.value ??
        const <AgentSession>[];
    final dev = const DeriveDevContext()(
      ticket,
      links: links,
      sessions: sessions,
      translationLoading: trStatus == TranslationState.loading,
    );

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
                                if (ticket.severity != null)
                                  SeverityTag(ticket.severity!)
                                else if (ticket.providerType !=
                                    ProviderType.zentao)
                                  Flexible(
                                    child: WorkspaceTag(wsColor, projectName),
                                  ),
                                const Spacer(),
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
                            if (dev.hasDev) ...[
                              SizedBox(height: context.spacing.md),
                              _DevRow(dev: dev),
                            ],
                            if (dev.agent != null) ...[
                              SizedBox(height: context.spacing.md),
                              _AgentChip(dev.agent!),
                            ],
                            if (zentaoBugResolution(ticket).isNotEmpty) ...[
                              SizedBox(height: context.spacing.md),
                              _ResolutionChip(ticket),
                            ],
                            SizedBox(height: context.spacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AssigneeChip(ticket.assignee, wsColor),
                                ),
                                SizedBox(width: context.spacing.sm),
                                Text(
                                  ticketRef(
                                    ticket.providerType,
                                    ticket.externalKey,
                                    ticket.externalType,
                                  ),
                                  style: context.typography.monoXs.copyWith(
                                    color: c.textTertiary,
                                  ),
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

class _ResolutionChip extends StatelessWidget {
  const _ResolutionChip(this.ticket);

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final resolution = zentaoBugResolution(ticket);
    final label = zentaoBugResolutionLabels[resolution] ?? resolution;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(c.accent, 0.12),
        borderRadius: BorderRadius.circular(context.radii.xs),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(c.accent, 0.28))
            : null,
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: context.typography.monoXs.copyWith(
          fontWeight: FontWeight.w600,
          color: c.accent,
        ),
      ),
    );
  }
}

class _DevRow extends StatelessWidget {
  const _DevRow({required this.dev});
  final DevContext dev;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.typography.monoXs.copyWith(color: c.textTertiary);
    return Row(
      children: [
        if (dev.branch != null)
          Expanded(
            child: Text(
              '⎇ ${dev.branch}',
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: c.textSecondary),
            ),
          ),
        if (dev.pr != null) ...[
          SizedBox(width: context.spacing.md),
          Text('⇢ ${dev.pr}', style: style.copyWith(color: c.textSecondary)),
        ],
        if (dev.commit != null) ...[
          SizedBox(width: context.spacing.md),
          Text('⌥ ${dev.commit}', style: style),
        ],
      ],
    );
  }
}

class _AgentChip extends StatelessWidget {
  const _AgentChip(this.agent);
  final DevAgentInfo agent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chip = agent.running ? c.warning : c.success;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(chip, 0.13),
        borderRadius: BorderRadius.circular(context.radii.xs),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(chip, 0.32))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: chip, shape: BoxShape.circle),
          ),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              '${agent.name} · ${agent.labelKey}',
              overflow: TextOverflow.ellipsis,
              style: context.typography.monoXs.copyWith(
                fontWeight: FontWeight.w600,
                color: chip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
