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

/// The GitHub PR metadata sidebar: editable Assignee + Reviewers (the actions
/// GitHub's PAT API supports), read-only Labels (no label API through a PAT), and
/// a participants roll-up. Milestone / time-tracking / reactions are intentionally
/// absent — GitHub exposes no PAT endpoint for them, so they aren't shown.
class GitHubPrSidebar extends StatelessWidget {
  const GitHubPrSidebar({
    super.key,
    required this.ticket,
    required this.entity,
    required this.assigneeEditorBuilder,
    required this.reviewersEditorBuilder,
    required this.avatarLoader,
  });

  final Ticket ticket;
  final GitHubItemEntity entity;
  final MetadataEditorBuilder assigneeEditorBuilder;
  final MetadataEditorBuilder reviewersEditorBuilder;
  final AvatarLoader avatarLoader;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final assignees = entity.assignees.isNotEmpty
        ? entity.assignees
        : [if ((ticket.assignee ?? '').isNotEmpty) ticket.assignee!];
    final labels = visibleUserLabels(ticket.labels);
    final participants = <String>{
      if ((entity.author ?? '').isNotEmpty) entity.author!,
      ...entity.assignees.where((name) => name.isNotEmpty),
      ...entity.reviewers.where((name) => name.isNotEmpty),
    }.toList();
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
              : _NameList(assignees, avatarLoader: avatarLoader),
        ),
        DetailSidebarSection(
          title: l.reviewers,
          action: l.edit,
          editorTitle: l.reviewers,
          editorBuilder: reviewersEditorBuilder,
          child: entity.reviewers.isEmpty
              ? _MutedText(l.noReviewersAssignYourself)
              : _NameList(entity.reviewers, avatarLoader: avatarLoader),
        ),
        DetailSidebarSection(
          title: l.labels,
          child: labels.isEmpty
              ? _MutedText(l.none)
              : LabelChips(labels: labels),
        ),
        DetailSidebarSection(
          title:
              '${participants.length} '
              '${participants.length == 1 ? l.participant : l.participants}',
          child: participants.isEmpty
              ? _MutedText(l.none)
              : _NameList(participants, avatarLoader: avatarLoader),
        ),
      ],
    );
  }
}

class _NameList extends StatelessWidget {
  const _NameList(this.names, {required this.avatarLoader});

  final List<String> names;
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
              avatarUrl: null,
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
