import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'zentao_formatters.dart';
import 'zentao_row_copy_actions.dart';
import 'zentao_task_row_parts.dart';

/// Modern interactive table row for ZenTao Tasks matching standard format:
/// ID -> Title -> Assignee -> Sprint -> Status -> Due.
class ZenTaoTaskRow extends ConsumerWidget {
  const ZenTaoTaskRow({super.key, required this.ticket});

  final Ticket ticket;

  static const _avatarPalette = [
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF06B6D4), // cyan
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final openId = ref.watch(openTicketIdProvider);
    final isSelected = openId == ticket.id;

    final (cleanTitle, moduleTag) = ZenTaoFormatters.extractModule(
      ticket.title,
    );
    final sprint = switch (ticket.providerEntity) {
      final ZenTaoTaskEntity task => task.executionName,
      _ => null,
    };
    final deadline = ZenTaoFormatters.extractDeadline(ticket);

    return HoverRegion(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered, _) {
        return HoverSurface(
          onTap: () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
          onSecondaryTapUp: (details) =>
              showZenTaoRowContextMenu(context, details.globalPosition, ticket),
          selected: isSelected,
          color: isSelected ? c.mixT(c.accent, 0.08) : Colors.transparent,
          hoverColor: c.surfaceSubtle,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.sm),
          child: Row(
            children: [
              // Column 1: ID
              SizedBox(
                width: 90,
                child: Text(
                  '#${ticket.externalKey}',
                  style: context.typography.monoSm.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: s.md),

              // Column 2: Title with [Module] tag prefix
              Expanded(
                child: Row(
                  children: [
                    if (moduleTag != null && moduleTag.isNotEmpty) ...[
                      Text(
                        moduleTag,
                        style: context.typography.body.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: s.xs),
                    ],
                    Expanded(
                      child: Text(
                        cleanTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isSelected ? c.accent : c.textPrimary,
                        ),
                      ),
                    ),
                    if (hovered) ...[
                      SizedBox(width: s.xs),
                      ZenTaoRowQuickCopyButton(ticket: ticket),
                    ],
                  ],
                ),
              ),
              SizedBox(width: s.md),

              // Column 3: Assignee
              SizedBox(
                width: 150,
                child: ZenTaoRowAssigneeDisplay(
                  assignee: ticket.assignee,
                  palette: _avatarPalette,
                  unassignedLabel: l.unassigned,
                ),
              ),
              SizedBox(width: s.md),

              // Column 4: Sprint
              SizedBox(width: 90, child: ZenTaoSprintTag(sprint: sprint)),
              SizedBox(width: s.md),

              // Column 5: Status
              SizedBox(
                width: 115,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ZenTaoRowStatusPill(ticket: ticket),
                ),
              ),
              SizedBox(width: s.md),

              // Column 6: Due
              SizedBox(width: 85, child: ZenTaoDueTag(deadline: deadline)),
            ],
          ),
        );
      },
    );
  }
}
