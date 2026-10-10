import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/my_work_status.dart';
import '../util/short_when.dart';
import 'my_work_meta.dart';

/// One assigned bug or task: its kind, title and when it last changed, over
/// a meta line with everything needed to triage it without opening it — the
/// reference, status, severity, priority, sprint, deadline and task tree.
/// Opens in the detail panel, and stays highlighted while open there.
class MyWorkRow extends ConsumerWidget {
  const MyWorkRow({super.key, required this.ticket, this.showStatus = true});

  final Ticket ticket;

  /// Off inside a status section, whose header already says it.
  final bool showStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    final selected = ref.watch(openTicketIdProvider) == ticket.id;
    final type = ticket.externalType?.toLowerCase();
    final bug = type == 'bug';
    final updated = ticket.updatedAt ?? ticket.createdAt;
    return Material(
      color: selected ? c.selectionFill : Colors.transparent,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => ref.read(openTicketIdProvider.notifier).open(ticket.id),
        borderRadius: BorderRadius.circular(context.radii.md),
        hoverColor: c.selectionFill,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZenTaoKindIcon(type),
              SizedBox(width: s.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong.copyWith(color: c.textPrimary),
                          ),
                        ),
                        if (updated != null) ...[
                          SizedBox(width: s.md),
                          Text(
                            shortWhen(context, updated),
                            style: t.caption.copyWith(color: c.textTertiary),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: s.sm),
                    Wrap(
                      spacing: s.md,
                      runSpacing: s.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ticketRef(
                            ticket.providerType,
                            ticket.externalKey,
                            ticket.externalType,
                          ),
                          style: t.monoSm.copyWith(color: c.textTertiary),
                        ),
                        if (showStatus)
                          MyWorkStatusChip(
                            label: myWorkStatusLabel(
                              l,
                              ticket.status,
                              bug: bug,
                            ),
                            color: myWorkStatusColor(c, ticket.status),
                          ),
                        if (ticket.severity != null)
                          SeverityTag(ticket.severity),
                        PriorityTag(ticket.providerType, ticket.priority),
                        ..._facts(context, l),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _facts(BuildContext context, AppL10n l) {
    final s = context.spacing;
    final nameWidth = s.xl6 * 5;
    return switch (ticket.providerEntity) {
      ZenTaoBugEntity(
        :final executionName,
        :final productName,
        :final deadline,
        :final activatedCount,
      ) =>
        [
          if (executionName ?? productName case final where?)
            MyWorkFact(
              icon: LucideIcons.kanban300,
              text: where,
              maxWidth: nameWidth,
            ),
          if (parseZenTaoDate(deadline) case final due?) MyWorkDueFact(due),
          if (activatedCount case final n? when n > 0)
            MyWorkFact(
              icon: LucideIcons.rotateCcw300,
              text: l.myWorkReopened(n),
              color: context.colors.warning,
            ),
        ],
      ZenTaoTaskEntity(:final parentName, :final subtasks) => [
        if (parentName case final parent? when parent.isNotEmpty)
          MyWorkFact(
            icon: LucideIcons.cornerLeftUp300,
            text: parent,
            maxWidth: nameWidth,
          ),
        if (subtasks.isNotEmpty)
          MyWorkFact(
            icon: LucideIcons.network300,
            text: l.myWorkSubtasks(subtasks.length),
          ),
      ],
      _ => const [],
    };
  }
}
