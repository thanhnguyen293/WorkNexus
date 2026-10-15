import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/github_pr_service.dart';
import '../../domain/usecases/close_github_item.dart';
import '../../domain/usecases/merge_github_pr.dart';
import '../../domain/usecases/post_github_comment.dart';
import '../../domain/usecases/reopen_github_item.dart';
import '../../domain/usecases/update_github_pr_branch.dart';

final gitHubPrServiceProvider = Provider<GitHubPrService>(
  (ref) => getIt<GitHubPrService>(),
);

final postGitHubCommentProvider = Provider<PostGitHubComment>(
  (ref) => PostGitHubComment(ref.watch(gitHubPrServiceProvider)),
);

final closeGitHubItemProvider = Provider<CloseGitHubItem>(
  (ref) => CloseGitHubItem(ref.watch(gitHubPrServiceProvider)),
);

final reopenGitHubItemProvider = Provider<ReopenGitHubItem>(
  (ref) => ReopenGitHubItem(ref.watch(gitHubPrServiceProvider)),
);

final mergeGitHubPrProvider = Provider<MergeGitHubPr>(
  (ref) => MergeGitHubPr(ref.watch(gitHubPrServiceProvider)),
);

final updateGitHubPrBranchProvider = Provider<UpdateGitHubPrBranch>(
  (ref) => UpdateGitHubPrBranch(ref.watch(gitHubPrServiceProvider)),
);
