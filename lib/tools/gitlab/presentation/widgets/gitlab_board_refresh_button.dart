import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/board/presentation/widgets/board_refresh_button.dart';
import '../providers/gitlab_board_providers.dart';

/// Refresh for the GitLab boards: fetches the selected project's items again.
class GitLabBoardRefreshButton extends ConsumerWidget {
  const GitLabBoardRefreshButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => BoardRefreshButton(
    loading: ref.watch(gitlabItemsSliceProvider).isLoading,
    onPressed: () => ref.invalidate(gitlabItemsSliceProvider),
  );
}
