import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../providers/github_board_providers.dart';

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
    return AppSegmentedTabs(
      tabs: [
        for (final kind in GitHubItemKind.values)
          AppSegmentedTab(
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

String _label(AppL10n l, GitHubItemKind kind) => switch (kind) {
  GitHubItemKind.issue => l.githubIssues,
  GitHubItemKind.pullRequest => l.githubPullRequests,
};
