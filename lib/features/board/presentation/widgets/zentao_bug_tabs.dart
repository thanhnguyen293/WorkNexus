import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../board_providers.dart';

/// The ZenTao bug-board tab strip (All / Unclosed / Reported by me / Assigned to
/// me / Resolved by me / Assigned by me). Each tab is a distinct server-side
/// view: selecting one refetches that browse type from ZenTao. The active tab
/// shows its result count (and a spinner while its fetch is in flight).
class ZenTaoBugTabs extends ConsumerWidget {
  const ZenTaoBugTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final active = ref.watch(zentaoBugTabProvider);
    final slice = ref.watch(zentaoBugTabSliceProvider);

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in ZenTaoBugBrowseType.values)
              _BugTab(
                label: _label(l, tab),
                active: tab == active,
                count: tab == active ? slice.asData?.value.length : null,
                loading: tab == active && slice.isLoading,
                onTap: () => ref.read(zentaoBugTabProvider.notifier).set(tab),
              ),
          ],
        ),
      ),
    );
  }
}

class _BugTab extends StatelessWidget {
  const _BugTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.loading = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? c.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.typography.bodySm.copyWith(
                color: active ? c.textPrimary : c.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (loading) ...[
              SizedBox(width: context.spacing.sm),
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: c.textTertiary,
                ),
              ),
            ] else if (count != null) ...[
              SizedBox(width: context.spacing.sm),
              _CountPill(count!, active: active),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.count, {required this.active});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: active ? c.mixT(c.accent, 0.14) : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        '$count',
        style: context.typography.monoXs.copyWith(
          color: active ? c.accent : c.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _label(AppL10n l, ZenTaoBugBrowseType tab) => switch (tab) {
  ZenTaoBugBrowseType.all => l.bugTabAll,
  ZenTaoBugBrowseType.unclosed => l.bugTabUnclosed,
  ZenTaoBugBrowseType.reportedByMe => l.bugTabReportedByMe,
  ZenTaoBugBrowseType.assignedToMe => l.assignedToMe,
  ZenTaoBugBrowseType.resolvedByMe => l.resolvedByMe,
  ZenTaoBugBrowseType.assignedByMe => l.bugTabAssignedByMe,
};
