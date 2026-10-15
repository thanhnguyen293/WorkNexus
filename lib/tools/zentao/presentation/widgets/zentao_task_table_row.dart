import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'zentao_formatters.dart';
import 'zentao_priority_badge.dart';
import 'zentao_status_pill.dart';

/// Single high-density row in the ZenTao Task Table View.
class ZenTaoTaskTableRow extends ConsumerStatefulWidget {
  const ZenTaoTaskTableRow({
    super.key,
    required this.ticket,
    this.selected = false,
    this.onToggleSelect,
  });

  final Ticket ticket;
  final bool selected;
  final ValueChanged<bool?>? onToggleSelect;

  @override
  ConsumerState<ZenTaoTaskTableRow> createState() => _ZenTaoTaskTableRowState();
}

class _ZenTaoTaskTableRowState extends ConsumerState<ZenTaoTaskTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = widget.ticket;
    final isSelectedTicket = ref.watch(openTicketIdProvider) == t.id;

    final deadline = ZenTaoFormatters.extractDeadline(t);
    final delayText = ZenTaoFormatters.calcDelayText(deadline);
    final (cleanTitle, moduleTag) = ZenTaoFormatters.extractModule(t.title);

    final rowBg = isSelectedTicket
        ? c.selectionFill
        : (_hovered ? c.surfaceSubtle : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => ref.read(appNavProvider.notifier).openTicket(t.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          decoration: BoxDecoration(
            color: rowBg,
            border: Border(bottom: context.hairlineSide),
          ),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: widget.selected,
                  onChanged: widget.onToggleSelect,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // ID
              SizedBox(
                width: 68,
                child: Text(
                  '#${t.externalKey}',
                  style: context.typography.monoXs.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // Name (Title + Module + Delay)
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    if (moduleTag != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c.selectionFill,
                          borderRadius: BorderRadius.circular(context.radii.xs),
                        ),
                        child: Text(
                          moduleTag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.monoXs.copyWith(
                            color: c.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        cleanTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.bodySm.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (delayText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: c.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(context.radii.xs),
                          border: Border.all(
                            color: c.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          delayText,
                          style: context.typography.monoXs.copyWith(
                            color: c.error,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // Priority Circle (①, ②, ③, ④)
              SizedBox(
                width: 36,
                child: Center(child: ZenTaoPriorityBadge(priority: t.priority)),
              ),
              SizedBox(width: context.spacing.xs),

              // Status
              SizedBox(
                width: 84,
                child: ZenTaoStatusPill(
                  status: t.status,
                  providerStatus: t.providerStatus,
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // AssignTo
              SizedBox(
                width: 110,
                child: Text(
                  t.assignee?.isNotEmpty == true ? t.assignee! : 'No assigned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySm.copyWith(
                    color: t.assignee?.isNotEmpty == true
                        ? c.textPrimary
                        : c.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // FinishedBy / -
              SizedBox(
                width: 100,
                child: Text(
                  '-',
                  style: context.typography.monoXs.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // Deadline
              SizedBox(
                width: 105,
                child: Text(
                  deadline != null
                      ? ZenTaoFormatters.formatDeadline(deadline)
                      : '-',
                  style: context.typography.monoXs.copyWith(
                    color: delayText != null ? c.error : c.textSecondary,
                    fontWeight: delayText != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xs),

              // Quick Actions
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    _MicroAction(
                      icon: Icons.play_arrow_outlined,
                      tooltip: 'Start',
                      onTap: () {},
                    ),
                    _MicroAction(
                      icon: Icons.check_circle_outline_rounded,
                      tooltip: 'Finish',
                      onTap: () {},
                    ),
                    _MicroAction(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onTap: () =>
                          ref.read(appNavProvider.notifier).openTicket(t.id),
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
}

class _MicroAction extends StatelessWidget {
  const _MicroAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.xs),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: c.textTertiary),
        ),
      ),
    );
  }
}
