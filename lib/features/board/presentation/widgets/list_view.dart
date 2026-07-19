import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../translation/presentation/translation_providers.dart';
import '../board_providers.dart';

// Column widths (design grid: 220 / 1fr / 150 / 128 / 132 / 56 / 60).
const _wTask = 220.0;
const _wProject = 150.0;
const _wPriority = 128.0;
const _wStatus = 132.0;
const _wVi = 56.0;
const _wUpdated = 120.0;
const _minTableWidth = 960.0;

class TaskListView extends ConsumerWidget {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(listRowsProvider);
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _minTableWidth,
          child: Column(
            children: [
              const _HeaderRow(),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _Row(rows[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.typography.labelWide.copyWith(color: c.textTertiary);
    Widget cell(String label, double w, {TextAlign align = TextAlign.left}) =>
        SizedBox(
          width: w,
          child: Text(label.toUpperCase(), style: s, textAlign: align),
        );
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.lg,
        context.spacing.md,
        context.spacing.xl2,
        context.spacing.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          cell(l.task, _wTask),
          Expanded(child: Text(l.summary.toUpperCase(), style: s)),
          cell(l.project, _wProject),
          cell(l.priority, _wPriority),
          cell(l.status, _wStatus),
          SizedBox(
            width: _wVi,
            child: Text('VI', style: s, textAlign: TextAlign.center),
          ),
          cell(l.updated, _wUpdated, align: TextAlign.right),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row(this.ticket);
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final wsColor = ws == null ? c.workspaceFallback : Color(ws.colorValue);
    final projectName = lookups.projects[ticket.projectId]?.name ?? '';
    final selected = ref.watch(openTicketIdProvider) == ticket.id;
    final trStatus = ref.watch(translationStatusProvider(ticket.id)).state;

    return InkWell(
      onTap: () => ref.read(openTicketIdProvider.notifier).open(ticket.id),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          context.spacing.lg,
          context.spacing.md,
          context.spacing.xl2,
          context.spacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? c.selectionFill : Colors.transparent,
          border: Border(
            left: BorderSide(color: wsColor, width: context.borders.accent),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _wTask - 3,
              child: Row(
                children: [
                  WorkspaceBadge(wsColor, ws?.shortCode ?? '?'),
                  SizedBox(width: context.spacing.sm),
                  ProviderBadge(ticket.providerType),
                  SizedBox(width: context.spacing.sm),
                  Flexible(
                    child: Text(
                      ticketRef(
                        ticket.providerType,
                        ticket.externalKey,
                        ticket.externalType,
                      ),
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.mono.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: context.spacing.xl),
                child: Text(
                  ticket.title,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.secondary.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _wProject,
              child: Text(
                projectName,
                overflow: TextOverflow.ellipsis,
                style: context.typography.meta.copyWith(color: c.textSecondary),
              ),
            ),
            SizedBox(
              width: _wPriority,
              child: Align(
                alignment: Alignment.centerLeft,
                child: PriorityTag(ticket.providerType, ticket.priority),
              ),
            ),
            SizedBox(
              width: _wStatus,
              child: Row(
                children: [
                  StatusDot(ticket.status, size: 7),
                  SizedBox(width: context.spacing.sm),
                  Text(
                    statusLabel(l, ticket.status),
                    style: context.typography.meta.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _wVi,
              child: Center(child: TranslationChip(trStatus)),
            ),
            SizedBox(
              width: _wUpdated,
              child: Text(
                formatWhen(
                  context,
                  ticket.updatedAt,
                  format: ref.watch(
                    appSettingsProvider.select((s) => s.dateFormat),
                  ),
                ),
                textAlign: TextAlign.right,
                style: context.typography.monoSm.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
