import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
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
