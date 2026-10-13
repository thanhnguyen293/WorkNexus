import 'package:flutter/material.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_spacing.dart';
import '../util/gitlab_mr_phase.dart';
import 'changed_files_section.dart';
import 'commits_section.dart';
import 'detail_activity_timeline.dart';
import 'detail_sidebar_section.dart';
import 'gitlab_mr_approval_panel.dart';
import 'gitlab_mr_commands.dart';
import 'gitlab_mr_header.dart';
import 'gitlab_mr_merge_panel.dart';
import 'gitlab_mr_outcome_panel.dart';
import 'gitlab_mr_sidebar.dart';
import 'item_description.dart';
import 'provider_user_avatar.dart';
import 'two_pane_tabbed_detail.dart';

/// The GitLab merge-request detail body: a header and a tabbed two-pane layout.
/// The Overview tab follows GitLab's order — description, approvals, the merge
/// widget (or how the MR ended), activity — beside the metadata sidebar;
/// Commits and Changed files live on their own tabs.
class GitLabMrOverview extends StatelessWidget {
  const GitLabMrOverview({
    super.key,
    required this.ticket,
    required this.entity,
    required this.isSyncing,
    required this.onClose,
    required this.onSync,
    required this.onComment,
    required this.commands,
    required this.commitsLoader,
    required this.changesLoader,
    required this.assigneeEditorBuilder,
    required this.reviewersEditorBuilder,
    required this.labelsEditorBuilder,
    required this.milestoneEditorBuilder,
    required this.timeTrackingEditorBuilder,
    required this.avatarLoader,
    this.comments = const <Comment>[],
    this.activity = const <ActivityEvent>[],
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final bool isSyncing;
  final VoidCallback onClose;
  final VoidCallback onSync;
  final Future<bool> Function(String body) onComment;
  final GitLabMrCommands commands;
  final CommitsLoader commitsLoader;
  final ChangedFilesLoader changesLoader;
  final MetadataEditorBuilder assigneeEditorBuilder;
  final MetadataEditorBuilder reviewersEditorBuilder;
  final MetadataEditorBuilder labelsEditorBuilder;
  final MetadataEditorBuilder milestoneEditorBuilder;
  final MetadataEditorBuilder timeTrackingEditorBuilder;
  final AvatarLoader avatarLoader;
  final List<Comment> comments;
  final List<ActivityEvent> activity;

  @override
  Widget build(BuildContext context) {
    final phase = gitLabMrPhase(ticket, entity);
    final open = phase.isActive;
    return TwoPaneTabbedDetail(
      isSyncing: isSyncing,
      header: GitLabMrHeader(
        ticket: ticket,
        entity: entity,
        onClose: onClose,
        onSync: onSync,
        commands: commands,
      ),
      overviewSections: [
        ItemDescription(ticket: ticket),
        SizedBox(height: context.spacing.xl5),
        if (GitLabMrApprovalPanel.shows(ticket, entity)) ...[
          GitLabMrApprovalPanel(
            ticket: ticket,
            entity: entity,
            commands: commands,
            avatarLoader: avatarLoader,
          ),
          SizedBox(height: context.spacing.md),
        ],
        if (open)
          GitLabMrMergePanel(ticket: ticket, entity: entity, commands: commands)
        else
          GitLabMrOutcomePanel(
            ticket: ticket,
            entity: entity,
            commands: commands,
          ),
        SizedBox(height: context.spacing.xl5),
        DetailActivityTimeline(
          comments: comments,
          activity: activity,
          onComment: onComment,
          onCloseItem: commands.close,
          canClose: open,
          onReopenItem: phase == GitLabMrPhase.closed ? commands.reopen : null,
        ),
      ],
      sidebar: GitLabMrSidebar(
        ticket: ticket,
        entity: entity,
        assigneeEditorBuilder: assigneeEditorBuilder,
        reviewersEditorBuilder: reviewersEditorBuilder,
        labelsEditorBuilder: labelsEditorBuilder,
        milestoneEditorBuilder: milestoneEditorBuilder,
        timeTrackingEditorBuilder: timeTrackingEditorBuilder,
        avatarLoader: avatarLoader,
      ),
      commits: CommitsSection(loader: commitsLoader),
      changes: ChangedFilesSection(loader: changesLoader),
      overviewCount: comments.length,
      changesCount: entity.changedFiles,
    );
  }
}
