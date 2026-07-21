import 'package:flutter/material.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_spacing.dart';
import 'changed_files_section.dart';
import 'commits_section.dart';
import 'detail_activity_timeline.dart';
import 'detail_sidebar_section.dart';
import 'github_pr_header.dart';
import 'github_pr_merge_panel.dart';
import 'github_pr_sidebar.dart';
import 'item_description.dart';
import 'provider_user_avatar.dart';
import 'two_pane_tabbed_detail.dart';

/// The GitHub pull-request detail body: a header and a tabbed two-pane layout.
/// The Overview tab shows description → merge widget → activity beside the
/// metadata sidebar; Commits and Changed files live on their own tabs. Mirrors
/// the GitLab MR overview.
class GitHubPrOverview extends StatelessWidget {
  const GitHubPrOverview({
    super.key,
    required this.ticket,
    required this.entity,
    required this.isSyncing,
    required this.onClose,
    required this.onSync,
    required this.onComment,
    required this.onCloseItem,
    required this.onReopen,
    required this.onMerge,
    required this.onUpdateBranch,
    required this.commitsLoader,
    required this.changesLoader,
    required this.assigneeEditorBuilder,
    required this.reviewersEditorBuilder,
    required this.avatarLoader,
    this.comments = const <Comment>[],
    this.activity = const <ActivityEvent>[],
  });

  final Ticket ticket;
  final GitHubItemEntity entity;
  final bool isSyncing;
  final VoidCallback onClose;
  final VoidCallback onSync;
  final Future<bool> Function(String body) onComment;
  final VoidCallback onCloseItem;
  final VoidCallback onReopen;
  final VoidCallback onMerge;
  final VoidCallback onUpdateBranch;
  final CommitsLoader commitsLoader;
  final ChangedFilesLoader changesLoader;
  final MetadataEditorBuilder assigneeEditorBuilder;
  final MetadataEditorBuilder reviewersEditorBuilder;
  final AvatarLoader avatarLoader;
  final List<Comment> comments;
  final List<ActivityEvent> activity;

  bool get _canClose {
    final raw = ticket.providerStatus.toLowerCase();
    return raw != 'merged' && raw != 'closed';
  }

  @override
  Widget build(BuildContext context) {
    return TwoPaneTabbedDetail(
      isSyncing: isSyncing,
      header: GitHubPrHeader(
        ticket: ticket,
        entity: entity,
        onClose: onClose,
        onSync: onSync,
      ),
      overviewSections: [
        ItemDescription(ticket: ticket),
        SizedBox(height: context.spacing.xl2),
        GitHubPrMergePanel(
          ticket: ticket,
          entity: entity,
          onMerge: onMerge,
          onUpdateBranch: onUpdateBranch,
          onReopen: onReopen,
        ),
        SizedBox(height: context.spacing.xl2),
        DetailActivityTimeline(
          comments: comments,
          activity: activity,
          onComment: onComment,
          onCloseItem: onCloseItem,
          canClose: _canClose,
        ),
      ],
      sidebar: GitHubPrSidebar(
        ticket: ticket,
        entity: entity,
        assigneeEditorBuilder: assigneeEditorBuilder,
        reviewersEditorBuilder: reviewersEditorBuilder,
        avatarLoader: avatarLoader,
      ),
      commits: CommitsSection(loader: commitsLoader),
      changes: ChangedFilesSection(loader: changesLoader),
    );
  }
}
