import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../l10n/app_localizations.dart';

/// Renders the 2 metrics on a workspace tool overview card:
/// displays count and label from the local DB, or a skeleton while loading (design §5).
class ToolCardMetrics extends ConsumerWidget {
  const ToolCardMetrics({
    super.key,
    required this.module,
    required this.account,
  });

  final ToolModule module;
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final asyncMetrics = ref.watch(module.metrics(account));

    return asyncMetrics.when(
      loading: () => const _MetricsSkeleton(),
      error: (_, _) => const _MetricsSkeleton(),
      data: (metrics) => Row(
        children: [
          Expanded(
            child: _MetricTile(
              count: metrics.primaryCount,
              label: metrics.primaryLabel(l),
            ),
          ),
          if (metrics.secondaryCount != null &&
              metrics.secondaryLabel != null) ...[
            SizedBox(width: s.lg),
            Expanded(
              child: _MetricTile(
                count: metrics.secondaryCount!,
                label: metrics.secondaryLabel!(l),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: context.typography.title.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: s.xxs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.captionSm.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;

    return Row(
      children: [
        const Expanded(child: _SingleSkeletonTile()),
        SizedBox(width: s.lg),
        const Expanded(child: _SingleSkeletonTile()),
      ],
    );
  }
}

class _SingleSkeletonTile extends StatelessWidget {
  const _SingleSkeletonTile();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 24,
          decoration: BoxDecoration(
            color: c.skeleton,
            borderRadius: BorderRadius.circular(r.sm),
          ),
        ),
        SizedBox(height: s.xs),
        Container(
          width: 72,
          height: 12,
          decoration: BoxDecoration(
            color: c.skeleton,
            borderRadius: BorderRadius.circular(r.xs),
          ),
        ),
      ],
    );
  }
}
