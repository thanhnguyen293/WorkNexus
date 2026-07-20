import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../board_providers.dart';

/// The GitHub board's kind tab strip (Issues / Pull Requests). Switching a tab
/// refetches that kind's items for the selected repo; the active tab shows its
/// result count (and a spinner while its fetch is in flight).
class GitHubTabs extends ConsumerWidget {
  const GitHubTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final active = ref.watch(githubKindProvider);
    final slice = ref.watch(githubItemsSliceProvider);
    final count = ref.watch(resultCountProvider);

    // Rendered inline on the ChromeBar toolbar row (see BoardPage).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in GitHubItemKind.values)
          _KindTab(
            label: _label(l, kind),
            active: kind == active,
            count: kind == active ? count : null,
            loading: kind == active && slice.isLoading,
            onTap: () => ref.read(githubKindProvider.notifier).set(kind),
          ),
      ],
    );
  }
}

class _KindTab extends StatelessWidget {
  const _KindTab({
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

String _label(AppL10n l, GitHubItemKind kind) => switch (kind) {
  GitHubItemKind.issue => l.githubIssues,
  GitHubItemKind.pullRequest => l.githubPullRequests,
};
