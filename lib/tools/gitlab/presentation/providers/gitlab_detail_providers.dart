import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../domain/usecases/approve_gitlab_mr.dart';
import '../../domain/usecases/close_gitlab_mr.dart';
import '../../domain/usecases/merge_gitlab_mr.dart';
import '../../domain/usecases/post_gitlab_mr_comment.dart';
import '../../domain/usecases/rebase_gitlab_mr.dart';
import '../../domain/usecases/reopen_gitlab_mr.dart';
import '../../domain/usecases/set_gitlab_mr_draft.dart';
import '../../domain/usecases/unapprove_gitlab_mr.dart';

final gitLabMrServiceProvider = Provider<GitLabMrService>(
  (ref) => getIt<GitLabMrService>(),
);

final postGitLabMrCommentProvider = Provider<PostGitLabMrComment>(
  (ref) => PostGitLabMrComment(ref.watch(gitLabMrServiceProvider)),
);

final closeGitLabMrProvider = Provider<CloseGitLabMr>(
  (ref) => CloseGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

final approveGitLabMrProvider = Provider<ApproveGitLabMr>(
  (ref) => ApproveGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

final unapproveGitLabMrProvider = Provider<UnapproveGitLabMr>(
  (ref) => UnapproveGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

final reopenGitLabMrProvider = Provider<ReopenGitLabMr>(
  (ref) => ReopenGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

final setGitLabMrDraftProvider = Provider<SetGitLabMrDraft>(
  (ref) => SetGitLabMrDraft(ref.watch(gitLabMrServiceProvider)),
);

final mergeGitLabMrProvider = Provider<MergeGitLabMr>(
  (ref) => MergeGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

final rebaseGitLabMrProvider = Provider<RebaseGitLabMr>(
  (ref) => RebaseGitLabMr(ref.watch(gitLabMrServiceProvider)),
);
