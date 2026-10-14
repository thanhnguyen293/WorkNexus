import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/task_bugs_providers.dart';
import 'detail_fields_card.dart';
import 'detail_region_card.dart';
import 'section_label.dart';

/// A ZenTao task's related bugs (the bugs whose `task` is this one) as a
/// sidebar card; tapping one opens it. The stored ones show at once while the
/// task's execution's bugs are fetched. Nothing shows while there are none,
/// unless the fetch failed — then it says so, with a retry. Spaces itself
/// from the card above.
class TaskBugsCard extends ConsumerWidget {
  const TaskBugsCard({super.key, required this.ticket});

  /// The task.
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final bugs = ref.watch(taskBugsProvider(ticket.id));
    final sync = ref.watch(taskBugsSyncProvider(ticket.id));
    final failed = sync.value is Err;
    if (bugs.isEmpty && !failed) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: DetailRegionCard(
        padding: detailSidebarInset(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SectionLabel('${l.relatedBugs} (${bugs.length})'),
                if (sync.isLoading) ...[
                  SizedBox(width: context.spacing.sm),
                  SizedBox.square(
                    dimension: context.sizes.iconXs,
                    child: const CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ],
              ],
            ),
            SizedBox(height: context.spacing.xs),
            for (final bug in bugs)
              _BugRow(
                bug: bug,
                onTap: () =>
                    ref.read(appNavProvider.notifier).openTicket(bug.id),
              ),
            if (failed)
              _LoadFailed(
                onRetry: () => ref.invalidate(taskBugsSyncProvider(ticket.id)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One related bug: its id and title (up to two lines), then its status.
class _BugRow extends StatelessWidget {
  const _BugRow({required this.bug, required this.onTap});

  final Ticket bug;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return HoverSurface(
      onTap: onTap,
      padding: EdgeInsets.symmetric(vertical: s.sm),
      border: Border(bottom: context.hairlineSide),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${bug.externalKey}',
            style: context.typography.mono.copyWith(color: c.textSecondary),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Text(
              bug.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typography.meta.copyWith(color: c.accent),
            ),
          ),
          SizedBox(width: s.md),
          TintedPill(
            color: statusColor(c, bug.status),
            label: statusLabel(AppL10n.of(context), bug.status),
          ),
        ],
      ),
    );
  }
}

/// The fetch failed: says so, with a retry link.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final style = context.typography.caption;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: context.spacing.sm,
        children: [
          Text(
            l.relatedBugsLoadFailed,
            style: style.copyWith(color: c.textTertiary),
          ),
          HoverRegion(
            // As the empty-fields link: focusable, underlined on hover.
            builder: (context, hovered, _) => HoverSurface(
              onTap: onRetry,
              tintOnHover: false,
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: Text(
                l.retry,
                style: style.copyWith(
                  color: c.accent,
                  decoration: hovered ? TextDecoration.underline : null,
                  decorationColor: c.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
