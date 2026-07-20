import 'package:flutter/material.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/theme/app_spacing.dart';
import 'sidebar_primitives.dart';

/// The per-account "Pinned" area shared by the GitLab and GitHub account nodes:
/// a "Pinned" header followed by the account's pinned projects/repos, lifted
/// above the collapsible projects group. Renders nothing when [pinned] is empty.
class ProviderPinnedProjects extends StatelessWidget {
  const ProviderPinnedProjects({
    super.key,
    required this.pinned,
    required this.rowBuilder,
  });

  /// The pinned projects/repos, already resolved against the account's loaded
  /// list (order preserved).
  final List<ProviderProject> pinned;

  /// Builds the row for one pinned entry — a `GitLabProjectRow` /
  /// `GitHubRepoRow` with `pinned: true`.
  final Widget Function(ProviderProject project) rowBuilder;

  @override
  Widget build(BuildContext context) {
    if (pinned.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SidebarPinnedHeader(),
          for (final p in pinned) rowBuilder(p),
        ],
      ),
    );
  }
}
