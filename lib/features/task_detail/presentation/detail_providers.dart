import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/adapters/github_pr_service.dart';
import '../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/dev_link.dart';
import '../../../core/domain/repositories/activity_repository.dart';
import '../../../core/domain/repositories/comment_repository.dart';
import '../../../core/domain/repositories/dev_link_repository.dart';
import '../../sync/data/sync_service.dart';
import '../domain/usecases/approve_gitlab_mr.dart';
import '../domain/usecases/close_github_item.dart';
import '../domain/usecases/close_gitlab_mr.dart';
import '../domain/usecases/merge_github_pr.dart';
import '../domain/usecases/merge_gitlab_mr.dart';
import '../domain/usecases/post_github_comment.dart';
import '../domain/usecases/post_gitlab_mr_comment.dart';
import '../domain/usecases/rebase_gitlab_mr.dart';
import '../domain/usecases/reopen_github_item.dart';
import '../domain/usecases/update_github_pr_branch.dart';

enum DetailTab { original, translation, comments, development }

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

final mergeGitLabMrProvider = Provider<MergeGitLabMr>(
  (ref) => MergeGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

final rebaseGitLabMrProvider = Provider<RebaseGitLabMr>(
  (ref) => RebaseGitLabMr(ref.watch(gitLabMrServiceProvider)),
);

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

/// Which detail tab is active (resets to original when a new ticket opens).
final detailTabProvider = NotifierProvider<DetailTabController, DetailTab>(
  DetailTabController.new,
);

class DetailTabController extends Notifier<DetailTab> {
  @override
  DetailTab build() => DetailTab.original;
  void set(DetailTab tab) => state = tab;
}

final commentsProvider = StreamProvider.family<List<Comment>, String>(
  (ref, id) => getIt<CommentRepository>().watchComments(id),
);

final activityProvider = StreamProvider.family<List<ActivityEvent>, String>(
  (ref, id) => getIt<ActivityRepository>().watchActivity(id),
);

final devLinksProvider = StreamProvider.family<List<DevLink>, String>(
  (ref, id) => getIt<DevLinkRepository>().watchDevLinks(id),
);

/// On opening a ticket, pull its full detail + comments from the provider into
/// drift. The panel `watch`es this to show a refresh indicator; the actual
/// content updates flow through the reactive ticket/comment streams.
///
/// `autoDispose`, and invalidated by the panel on every open, so a ticket's
/// detail is always fetched fresh — never served from a previous open's result.
final ticketDetailSyncProvider = FutureProvider.autoDispose
    .family<void, String>((ref, id) async {
      final ticket = ref.read(ticketByIdProvider(id));
      if (ticket == null) return;
      await getIt<SyncService>().syncTicketDetail(ticket);
    });
