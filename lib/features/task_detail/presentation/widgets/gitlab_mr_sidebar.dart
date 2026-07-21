import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/label_chips.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_sidebar_section.dart';
import 'provider_user_avatar.dart';

class GitLabMrSidebar extends StatelessWidget {
  const GitLabMrSidebar({
    super.key,
    required this.ticket,
    required this.entity,
    required this.assigneeEditorBuilder,
    required this.reviewersEditorBuilder,
    required this.labelsEditorBuilder,
    required this.milestoneEditorBuilder,
    required this.timeTrackingEditorBuilder,
    required this.avatarLoader,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final MetadataEditorBuilder assigneeEditorBuilder;
  final MetadataEditorBuilder reviewersEditorBuilder;
  final MetadataEditorBuilder labelsEditorBuilder;
  final MetadataEditorBuilder milestoneEditorBuilder;
  final MetadataEditorBuilder timeTrackingEditorBuilder;
  final AvatarLoader avatarLoader;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final assignees = entity.assignees.isNotEmpty
        ? entity.assignees
        : [if ((ticket.assignee ?? '').isNotEmpty) ticket.assignee!];
    final labels = visibleUserLabels(ticket.labels);
    final avatarUrls = {
      ...entity.userAvatarUrls,
      if ((entity.author ?? '').isNotEmpty &&
          (entity.authorAvatarUrl ?? '').isNotEmpty)
        entity.author!: entity.authorAvatarUrl!,
    };
    final participants = <String>{
      if ((entity.author ?? '').isNotEmpty) entity.author!,
      ...entity.assignees.where((name) => name.isNotEmpty),
      ...entity.reviewers.where((name) => name.isNotEmpty),
    }.toList();
    final estimate = entity.humanTimeEstimate;
    final spent = entity.humanTotalTimeSpent;
    final timeSummary = [
      if (estimate != null && estimate.isNotEmpty) l.estimateSummary(estimate),
      if (spent != null && spent.isNotEmpty) l.spentSummary(spent),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSidebarSection(
          title: l.assignee,
          action: l.edit,
          editorTitle: l.assignee,
          editorBuilder: assigneeEditorBuilder,
          child: assignees.isEmpty
              ? _MutedText(l.none)
              : _NameList(
                  assignees,
                  avatarUrls: avatarUrls,
                  avatarLoader: avatarLoader,
                ),
        ),
        DetailSidebarSection(
          title: l.reviewers,
          action: l.edit,
          editorTitle: l.reviewers,
          editorBuilder: reviewersEditorBuilder,
          child: entity.reviewers.isEmpty
              ? _MutedText(l.noReviewersAssignYourself)
              : _NameList(
                  entity.reviewers,
                  avatarUrls: avatarUrls,
                  avatarLoader: avatarLoader,
                ),
        ),
        DetailSidebarSection(
          title: l.labels,
          action: l.edit,
          editorTitle: l.labels,
          editorBuilder: labelsEditorBuilder,
          child: labels.isEmpty
              ? _MutedText(l.none)
              : LabelChips(
                  labels: labels,
                  colors: entity.labelColors,
                  textColors: entity.labelTextColors,
                ),
        ),
        DetailSidebarSection(
          title: l.milestone,
          action: l.edit,
          editorTitle: l.milestone,
          editorBuilder: milestoneEditorBuilder,
          child: _MutedText(entity.milestoneTitle ?? l.none),
        ),
        DetailSidebarSection(
          title: l.timeTracking,
          trailingIcon: Icons.add,
          actionTooltip: l.editTimeTracking,
          editorTitle: l.timeTracking,
          editorBuilder: timeTrackingEditorBuilder,
          child: _MutedText(
            timeSummary.isEmpty ? l.noEstimateOrTimeSpent : timeSummary,
          ),
        ),
        DetailSidebarSection(
          title:
              '${participants.length} '
              '${participants.length == 1 ? l.participant : l.participants}',
          child: participants.isEmpty
              ? _MutedText(l.none)
              : _NameList(
                  participants,
                  avatarUrls: avatarUrls,
                  avatarLoader: avatarLoader,
                ),
        ),
      ],
    );
  }
}

class _NameList extends StatelessWidget {
  const _NameList(
    this.names, {
    required this.avatarUrls,
    required this.avatarLoader,
  });

  final List<String> names;
  final Map<String, String> avatarUrls;
  final AvatarLoader avatarLoader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in names)
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.xs),
            child: ProviderUserAvatar(
              name: name,
              avatarUrl: avatarUrls[name],
              imageLoader: avatarLoader,
            ),
          ),
      ],
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.typography.secondary.copyWith(
        color: context.colors.textTertiary,
      ),
    );
  }
}
