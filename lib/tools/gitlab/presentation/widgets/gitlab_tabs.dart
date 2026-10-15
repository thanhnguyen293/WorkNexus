import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../providers/gitlab_board_providers.dart';

/// The GitLab board's kind tab strip (Issues / Merge Requests). Switching a tab
/// refetches that kind's items for the selected project; the active tab shows
/// its result count (and a spinner while its fetch is in flight).
class GitLabTabs extends ConsumerWidget {
  const GitLabTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final active = ref.watch(gitlabKindProvider);
    final slice = ref.watch(gitlabItemsSliceProvider);
    final count = ref.watch(resultCountProvider);

    // Rendered inline on the ChromeBar toolbar row (see BoardPage).
    return AppSegmentedTabs(
      tabs: [
        for (final kind in GitLabItemKind.values)
          AppSegmentedTab(
            label: _label(l, kind),
            active: kind == active,
            count: kind == active ? count : null,
            loading: kind == active && slice.isLoading,
            onTap: () => ref.read(gitlabKindProvider.notifier).set(kind),
          ),
      ],
    );
  }
}

String _label(AppL10n l, GitLabItemKind kind) => switch (kind) {
  GitLabItemKind.issue => l.gitlabIssues,
  GitLabItemKind.mergeRequest => l.gitlabMergeRequests,
};
