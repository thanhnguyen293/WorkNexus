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
import 'gitlab_mr_header.dart';
import 'gitlab_mr_panels.dart';
import 'gitlab_mr_sidebar.dart';
import 'item_description.dart';
import 'provider_user_avatar.dart';

/// Below this panel width the content + metadata sidebar stack vertically;
/// above it they sit side by side.
const double kMrTwoPaneBreakpoint = 820;

/// The GitLab merge-request detail body: a header, a scrolling content column
/// (description → merge widget → activity), and a metadata sidebar (side-by-side
/// when wide, stacked below when narrow).
class GitLabMrOverview extends StatelessWidget {
  const GitLabMrOverview({
    super.key,
    required this.ticket,
    required this.entity,
    required this.isSyncing,
    required this.onClose,
    required this.onSync,
    required this.onComment,
    required this.onCloseMergeRequest,
    required this.onApprove,
    required this.onMerge,
    required this.onRebase,
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
  final VoidCallback onCloseMergeRequest;
  final VoidCallback onApprove;
  final VoidCallback onMerge;
  final VoidCallback onRebase;
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
          GitLabMrHeader(
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
                final compact = constraints.maxWidth < kMrTwoPaneBreakpoint;
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
      GitLabMrMergePanel(
        ticket: ticket,
        entity: entity,
        onApprove: onApprove,
        onMerge: onMerge,
        onRebase: onRebase,
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
        onCloseItem: onCloseMergeRequest,
        canClose: _canClose,
      ),
      if (compact) ...[SizedBox(height: context.spacing.xl2), _sidebar()],
    ];
  }

  GitLabMrSidebar _sidebar() => GitLabMrSidebar(
    ticket: ticket,
    entity: entity,
    assigneeEditorBuilder: assigneeEditorBuilder,
    reviewersEditorBuilder: reviewersEditorBuilder,
    labelsEditorBuilder: labelsEditorBuilder,
    milestoneEditorBuilder: milestoneEditorBuilder,
    timeTrackingEditorBuilder: timeTrackingEditorBuilder,
    avatarLoader: avatarLoader,
  );
}
