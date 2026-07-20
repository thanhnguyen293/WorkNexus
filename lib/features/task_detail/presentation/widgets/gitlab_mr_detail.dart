import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/post_gitlab_mr_comment.dart';
import '../detail_providers.dart';
import 'gitlab_mr_overview.dart';
import 'labels_editor.dart';
import 'milestone_editor.dart';
import 'time_tracking_editor.dart';
import 'user_picker_editor.dart';

class GitLabMrDetail extends ConsumerWidget {
  const GitLabMrDetail({
    super.key,
    required this.ticket,
    required this.entity,
    required this.isSyncing,
    required this.onClose,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final bool isSyncing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final sync = ref.watch(gitLabMrServiceProvider);
    final postComment = ref.watch(postGitLabMrCommentProvider);
    final closeMergeRequest = ref.watch(closeGitLabMrProvider);
    final approve = ref.watch(approveGitLabMrProvider);
    final merge = ref.watch(mergeGitLabMrProvider);
    final rebase = ref.watch(rebaseGitLabMrProvider);
    final comments =
        ref.watch(commentsProvider(ticket.id)).asData?.value ?? const <Never>[];
    final activity =
        ref.watch(activityProvider(ticket.id)).asData?.value ?? const <Never>[];
    return GitLabMrOverview(
      ticket: ticket,
      entity: entity,
      isSyncing: isSyncing,
      comments: comments,
      activity: activity,
      onClose: onClose,
      onSync: () => ref.invalidate(ticketDetailSyncProvider(ticket.id)),
      onComment: (body) => _postComment(context, postComment, ticket, body),
      onCloseMergeRequest: () => _run(
        context,
        closeMergeRequest(ticket),
        l.gitlabMrClosed(ticket.externalKey),
      ),
      onApprove: () => _run(
        context,
        approve(ticket),
        l.gitlabMrApproved(ticket.externalKey),
      ),
      onMerge: () =>
          _run(context, merge(ticket), l.gitlabMrMerged(ticket.externalKey)),
      onRebase: () =>
          _run(context, rebase(ticket), l.gitlabMrRebased(ticket.externalKey)),
      assigneeEditorBuilder: (_, close) => UserPickerEditor(
        currentUsers: entity.assignees.isNotEmpty
            ? entity.assignees
            : [if ((ticket.assignee ?? '').isNotEmpty) ticket.assignee!],
        multiple: false,
        loadUsers: () => sync.listUsers(ticket),
        onSave: (accounts) =>
            sync.assignTicket(ticket, assignee: accounts.first),
        onClose: close,
        avatarLoader: (url) => sync.fetchTicketImage(ticket, url),
      ),
      reviewersEditorBuilder: (_, close) => UserPickerEditor(
        currentUsers: entity.reviewers,
        multiple: true,
        loadUsers: () => sync.listUsers(ticket),
        onSave: (accounts) => sync.setReviewers(ticket, accounts),
        onClose: close,
        avatarLoader: (url) => sync.fetchTicketImage(ticket, url),
      ),
      labelsEditorBuilder: (_, close) => LabelsEditor(
        currentLabels: visibleUserLabels(ticket.labels),
        loadOptions: () => sync.listGitLabLabels(ticket),
        onSave: (labels) => sync.setGitLabLabels(ticket, labels),
        onClose: close,
      ),
      milestoneEditorBuilder: (_, close) => MilestoneEditor(
        currentMilestoneId: entity.milestoneId,
        loadOptions: () => sync.listGitLabMilestones(ticket),
        onSave: (milestoneId) => sync.setGitLabMilestone(ticket, milestoneId),
        onClose: close,
      ),
      timeTrackingEditorBuilder: (_, close) => TimeTrackingEditor(
        currentEstimate: entity.humanTimeEstimate,
        currentSpent: entity.humanTotalTimeSpent,
        onSave:
            ({estimate, spent, resetEstimate = false, resetSpent = false}) =>
                sync.updateGitLabTimeTracking(
                  ticket,
                  estimate: estimate,
                  spent: spent,
                  resetEstimate: resetEstimate,
                  resetSpent: resetSpent,
                ),
        onClose: close,
      ),
      avatarLoader: (url) => sync.fetchTicketImage(ticket, url),
    );
  }

  Future<bool> _postComment(
    BuildContext context,
    PostGitLabMrComment postComment,
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
