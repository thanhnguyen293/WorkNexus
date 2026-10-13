import 'package:flutter/material.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'comment_tile.dart';
import 'detail_section_title.dart';

/// Shared activity timeline (comments + system events, merged and time-sorted)
/// plus a composer, used by the GitLab MR and GitHub PR two-pane details. Like
/// GitLab's, entries hang off one rail — an icon per event, an avatar and a
/// card per comment — with "actor action · time" on a single line. The
/// "Close" secondary action only shows while the item can still be closed.
class DetailActivityTimeline extends StatefulWidget {
  const DetailActivityTimeline({
    super.key,
    required this.comments,
    required this.activity,
    required this.onComment,
    required this.onCloseItem,
    required this.canClose,
    this.onReopenItem,
  });

  final List<Comment> comments;
  final List<ActivityEvent> activity;
  final Future<bool> Function(String body) onComment;
  final VoidCallback onCloseItem;
  final bool canClose;

  /// Offers "Reopen" beside the comment button when set (a closed item).
  final VoidCallback? onReopenItem;

  @override
  State<DetailActivityTimeline> createState() => _DetailActivityTimelineState();
}

class _DetailActivityTimelineState extends State<DetailActivityTimeline> {
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    final ok = await widget.onComment(text);
    if (!mounted) return;
    setState(() => _posting = false);
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final entries = <_TimelineEntry>[
      for (final comment in widget.comments)
        _TimelineEntry(at: comment.createdAt, comment: comment),
      for (final event in widget.activity.where((e) => e.action != 'commented'))
        _TimelineEntry(at: event.at, activity: event),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSectionTitle(l.activity),
        if (entries.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.md),
            child: Text(
              l.noActivityYet,
              style: context.typography.secondary.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
          )
        else
          for (final (i, entry) in entries.indexed)
            switch (entry) {
              _TimelineEntry(:final comment?) => CommentTile(
                comment,
                isFirst: i == 0,
                isLast: i == entries.length - 1,
              ),
              _TimelineEntry(:final activity?) => ActivityRow(
                activity,
                isFirst: i == 0,
                isLast: i == entries.length - 1,
              ),
              _ => const SizedBox.shrink(),
            },
        SizedBox(height: context.spacing.xl),
        _Composer(
          controller: _controller,
          posting: _posting,
          onPost: _post,
          onCloseItem: widget.onCloseItem,
          canClose: widget.canClose,
          onReopenItem: widget.onReopenItem,
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.posting,
    required this.onPost,
    required this.onCloseItem,
    required this.canClose,
    required this.onReopenItem,
  });

  final TextEditingController controller;
  final bool posting;
  final VoidCallback onPost;
  final VoidCallback onCloseItem;
  final bool canClose;
  final VoidCallback? onReopenItem;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.borderStrong),
          ),
          child: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            style: context.typography.body.copyWith(color: c.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(context.spacing.lg),
              hintText: l.writeCommentHint,
              hintStyle: context.typography.body.copyWith(
                color: c.textTertiary,
              ),
            ),
          ),
        ),
        SizedBox(height: context.spacing.lg),
        Wrap(
          spacing: context.spacing.md,
          runSpacing: context.spacing.md,
          children: [
            AppButton.filled(
              size: AppButtonSize.small,
              isLoading: posting,
              onPressed: posting ? null : onPost,
              child: Text(l.commentAction),
            ),
            if (canClose)
              AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                onPressed: onCloseItem,
                child: Text(l.close),
              ),
            if (onReopenItem case final reopen?)
              AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                onPressed: reopen,
                child: Text(l.gitlabReopen),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.at, this.comment, this.activity});

  final DateTime at;
  final Comment? comment;
  final ActivityEvent? activity;
}
