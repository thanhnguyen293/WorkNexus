import 'package:flutter/material.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared activity timeline (comments + system events, merged and time-sorted)
/// plus a composer, used by the GitLab MR and GitHub PR two-pane details. The
/// "Close" secondary action only shows while the item can still be closed.
class DetailActivityTimeline extends StatefulWidget {
  const DetailActivityTimeline({
    super.key,
    required this.comments,
    required this.activity,
    required this.onComment,
    required this.onCloseItem,
    required this.canClose,
  });

  final List<Comment> comments;
  final List<ActivityEvent> activity;
  final Future<bool> Function(String body) onComment;
  final VoidCallback onCloseItem;
  final bool canClose;

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
        Text(
          l.activity,
          style: context.typography.display.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: context.spacing.lg),
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
          for (final entry in entries)
            entry.comment == null
                ? _ActivityEventRow(
                    actor: entry.activity!.actor,
                    text: entry.activity!.detail ?? entry.activity!.action,
                  )
                : _CommentRow(comment: entry.comment!),
        SizedBox(height: context.spacing.xl),
        _Composer(
          controller: _controller,
          posting: _posting,
          onPost: _post,
          onCloseItem: widget.onCloseItem,
          canClose: widget.canClose,
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
  });

  final TextEditingController controller;
  final bool posting;
  final VoidCallback onPost;
  final VoidCallback onCloseItem;
  final bool canClose;

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
          ],
        ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return _ActivityShell(
      actor: comment.authorName,
      child: MarkdownText(comment.body),
    );
  }
}

class _ActivityEventRow extends StatelessWidget {
  const _ActivityEventRow({required this.actor, required this.text});

  final String actor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _ActivityShell(actor: actor, child: Text(text));
  }
}

class _ActivityShell extends StatelessWidget {
  const _ActivityShell({required this.actor, required this.child});

  final String actor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: context.typography.body.copyWith(color: c.accent)),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                DefaultTextStyle(
                  style: context.typography.body.copyWith(
                    color: c.textSecondary,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.at, this.comment, this.activity});

  final DateTime at;
  final Comment? comment;
  final ActivityEvent? activity;
}
