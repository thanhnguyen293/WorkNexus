import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/board/presentation/widgets/board_refresh_button.dart';
import '../providers/github_board_providers.dart';

/// Refresh for the GitHub boards: fetches the selected repository's items
/// again.
class GitHubBoardRefreshButton extends ConsumerWidget {
  const GitHubBoardRefreshButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => BoardRefreshButton(
    loading: ref.watch(githubItemsSliceProvider).isLoading,
    onPressed: () => ref.invalidate(githubItemsSliceProvider),
  );
}
