import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../board_providers.dart';
import 'filter_facet_groups.dart';
import 'filter_generic_groups.dart';
import 'saved_filters_section.dart';

/// The advanced-filter dropdown. Saved presets sit on top, then the board's own
/// groups: context-aware — ZenTao bug/task boards (and the GitLab MR board) show
/// data-derived facet groups, the generic board/list show the cross-provider
/// groups (provider/account/project/status/priority).
class FilterPopover extends ConsumerWidget {
  const FilterPopover({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    final gitlabMr =
        mode == ViewMode.gitlab &&
        ref.watch(gitlabKindProvider) == GitLabItemKind.mergeRequest;
    final usesFacetFilters =
        mode == ViewMode.zentaoBugs || mode == ViewMode.zentaoTasks || gitlabMr;
    return _PopoverShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PopoverHeader(),
          SizedBox(height: context.spacing.lg),
          const SavedFiltersSection(),
          if (usesFacetFilters)
            const FacetFilterGroups()
          else
            const GenericFilterGroups(),
        ],
      ),
    );
  }
}

/// The popover's title, how many filters are on, and the reset.
class _PopoverHeader extends ConsumerWidget {
  const _PopoverHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final filter = ref.watch(filterStateProvider);
    final count = filter.activeTokenCount;
    return Row(
      children: [
        Text(
          l.filters,
          style: context.typography.bodySmStrong.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        if (count > 0) ...[
          SizedBox(width: context.spacing.sm),
          AppCountBadge(count, active: true),
        ],
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          icon: LucideIcons.rotateCcw300,
          isDisabled: !filter.hasActiveFilters,
          onPressed: ref.read(filterStateProvider.notifier).clearAll,
          child: Text(l.filtersClearAll),
        ),
      ],
    );
  }
}

class _PopoverShell extends StatelessWidget {
  const _PopoverShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.borderStrong),
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl2,
        context.spacing.xl,
        context.spacing.xl2,
        context.spacing.xl2,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}
