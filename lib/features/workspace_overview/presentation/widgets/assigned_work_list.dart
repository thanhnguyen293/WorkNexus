import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/assigned_work_item.dart';
import '../providers/overview_providers.dart';
import 'assigned_work_row.dart';

/// The "Assigned to you (from all tools)" section on the Workspace Overview
/// (design §5, specs S6.1). Shows open items sorted by urgency, capped at 20
/// with a "Show all {n}" toggle.
class AssignedWorkList extends ConsumerStatefulWidget {
  const AssignedWorkList({super.key, this.items});

  final List<AssignedWorkItem>? items;

  @override
  ConsumerState<AssignedWorkList> createState() => _AssignedWorkListState();
}

class _AssignedWorkListState extends ConsumerState<AssignedWorkList> {
  static const int _kInitialCap = 20;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);

    final List<AssignedWorkItem> workItems =
        widget.items ?? ref.watch(assignedWorkProvider);
    final totalCount = workItems.length;
    final hasOverflow = totalCount > _kInitialCap;
    final displayItems = _expanded || !hasOverflow
        ? workItems
        : workItems.take(_kInitialCap).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(r.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ListHeader(count: totalCount),
          Divider(height: 1, color: c.border),
          if (workItems.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.xl3),
              child: Center(
                child: Text(
                  l.noAssignedWork,
                  style: context.typography.bodySm.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.all(s.sm),
              child: Column(
                children: [
                  for (var i = 0; i < displayItems.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: c.border),
                    AssignedWorkRow(item: displayItems[i]),
                  ],
                ],
              ),
            ),
            if (hasOverflow) ...[
              Divider(height: 1, color: c.border),
              Padding(
                padding: EdgeInsets.all(s.md),
                child: Center(
                  child: AppButton.text(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? l.viewList : l.showAllWithCount(totalCount),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.lg),
      child: Row(
        children: [
          Text(
            l.assignedToYou,
            style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
          ),
          SizedBox(width: s.sm),
          Text(
            l.fromAllTools,
            style: context.typography.captionSm.copyWith(color: c.textTertiary),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(context.radii.pill),
            ),
            child: Text(
              '$count',
              style: context.typography.captionSm.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
