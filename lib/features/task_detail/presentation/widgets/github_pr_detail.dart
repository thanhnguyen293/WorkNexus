import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/post_github_comment.dart';
import '../detail_providers.dart';
import 'github_pr_overview.dart';
import 'user_picker_editor.dart';

/// Wires the GitHub PR two-pane [GitHubPrOverview] to its use cases + service
/// (via providers). Every state action shows a loading/success/error snackbar
/// and refreshes through the optimistic SyncService path; assign / reviewers go
/// straight to the service (metadata edits, like the GitLab MR detail).
class GitHubPrDetail extends ConsumerWidget {
  const GitHubPrDetail({
    super.key,
    required this.ticket,
    required this.entity,
    required this.isSyncing,
    required this.onClose,
  });

  final Ticket ticket;
  final GitHubItemEntity entity;
  final bool isSyncing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final service = ref.watch(gitHubPrServiceProvider);
    final postComment = ref.watch(postGitHubCommentProvider);
    final closeItem = ref.watch(closeGitHubItemProvider);
    final reopenItem = ref.watch(reopenGitHubItemProvider);
    final merge = ref.watch(mergeGitHubPrProvider);
    final updateBranch = ref.watch(updateGitHubPrBranchProvider);
    final comments =
        ref.watch(commentsProvider(ticket.id)).asData?.value ?? const <Never>[];
    final activity =
        ref.watch(activityProvider(ticket.id)).asData?.value ?? const <Never>[];
    return GitHubPrOverview(
      ticket: ticket,
      entity: entity,
      isSyncing: isSyncing,
      comments: comments,
      activity: activity,
      onClose: onClose,
      onSync: () => ref.invalidate(ticketDetailSyncProvider(ticket.id)),
      onComment: (body) => _postComment(context, postComment, ticket, body),
      onCloseItem: () => _run(
        context,
        closeItem(ticket),
        l.githubItemClosed(ticket.externalKey),
      ),
      onReopen: () => _run(
        context,
        reopenItem(ticket),
        l.githubItemReopened(ticket.externalKey),
      ),
      onMerge: () =>
          _run(context, merge(ticket), l.githubPrMerged(ticket.externalKey)),
      onUpdateBranch: () => _run(
        context,
        updateBranch(ticket),
        l.githubPrBranchUpdated(ticket.externalKey),
      ),
      assigneeEditorBuilder: (_, close) => UserPickerEditor(
        currentUsers: entity.assignees.isNotEmpty
            ? entity.assignees
            : [if ((ticket.assignee ?? '').isNotEmpty) ticket.assignee!],
        multiple: false,
        loadUsers: () => service.listUsers(ticket),
        onSave: (accounts) =>
            service.assignTicket(ticket, assignee: accounts.first),
        onClose: close,
        avatarLoader: (url) => service.fetchTicketImage(ticket, url),
      ),
      reviewersEditorBuilder: (_, close) => UserPickerEditor(
        currentUsers: entity.reviewers,
        multiple: true,
        loadUsers: () => service.listUsers(ticket),
        onSave: (accounts) => service.setReviewers(ticket, accounts),
        onClose: close,
        avatarLoader: (url) => service.fetchTicketImage(ticket, url),
      ),
      avatarLoader: (url) => service.fetchTicketImage(ticket, url),
    );
  }

  Future<bool> _postComment(
    BuildContext context,
    PostGitHubComment postComment,
    Ticket ticket,
    String body,
  ) async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final res = await postComment(ticket, body);
    if (!context.mounted) return false;
    if (res case Err<void>()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.actionFailed(res.failureOrNull?.message ?? l.commentPostFailed),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _run(
    BuildContext context,
    Future<Result<void>> action,
    String okMessage,
  ) async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final res = await action;
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          res.isOk
              ? okMessage
              : l.actionFailed(
                  res.failureOrNull?.message ?? l.providerActionFailed,
                ),
        ),
      ),
    );
  }
}
