import 'package:flutter/material.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
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

/// Below this panel width the content + metadata sidebar stack vertically.
const double kPrTwoPaneBreakpoint = 820;

/// The GitHub pull-request detail body: header, a scrolling content column
/// (description → merge widget → activity), and a metadata sidebar (side-by-side
/// when wide, stacked below when narrow). Mirrors the GitLab MR overview.
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
    final c = context.colors;
    return Material(
      color: c.card,
      child: Column(
        children: [
          GitHubPrHeader(
            ticket: ticket,
            entity: entity,
            onClose: onClose,
            onSync: onSync,
          ),
          if (isSyncing)
            LinearProgressIndicator(
              minHeight: context.borders.thick,
              backgroundColor: Colors.transparent,
              color: c.accent,
            )
          else
            SizedBox(height: context.borders.hairline),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < kPrTwoPaneBreakpoint;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.xl3,
                    context.spacing.xl2,
                    context.spacing.xl3,
                    context.spacing.xl3,
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _sections(context, compact: true),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _sections(context, compact: false),
                              ),
                            ),
                            SizedBox(width: context.spacing.xl3),
                            SizedBox(
                              width: context.spacing.xl6 * 6,
                              child: _sidebar(),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, {required bool compact}) {
    return [
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
      CommitsSection(loader: commitsLoader),
      SizedBox(height: context.spacing.xl2),
      ChangedFilesSection(loader: changesLoader),
      SizedBox(height: context.spacing.xl2),
      DetailActivityTimeline(
        comments: comments,
        activity: activity,
        onComment: onComment,
        onCloseItem: onCloseItem,
        canClose: _canClose,
      ),
      if (compact) ...[SizedBox(height: context.spacing.xl2), _sidebar()],
    ];
  }

  GitHubPrSidebar _sidebar() => GitHubPrSidebar(
    ticket: ticket,
    entity: entity,
    assigneeEditorBuilder: assigneeEditorBuilder,
    reviewersEditorBuilder: reviewersEditorBuilder,
    avatarLoader: avatarLoader,
  );
}
