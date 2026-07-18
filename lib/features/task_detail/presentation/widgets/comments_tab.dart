import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../detail_providers.dart';
import 'comment_tile.dart';
import 'detail_scroll_body.dart';

/// The "Comments & activity" tab — a merged timeline plus a composer.
class CommentsTab extends ConsumerStatefulWidget {
  const CommentsTab({super.key, required this.ticketId, required this.layout});
  final String ticketId;
  final DetailLayout layout;

  @override
  ConsumerState<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<CommentsTab> {
  final _ctrl = TextEditingController();
  bool _internal = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(commentRepositoryProvider)
        .addComment(
          Comment(
            id: '${widget.ticketId}:${DateTime.now().microsecondsSinceEpoch}',
            ticketId: widget.ticketId,
            authorName: 'You',
            body: text,
            createdAt: DateTime.now(),
            origin: _internal
                ? CommentOrigin.internalNote
                : CommentOrigin.provider,
            synced: !_internal ? false : true,
          ),
        );
    _ctrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Document layout caps the reading column; two-pane fills the panel.
    final maxW = widget.layout == DetailLayout.document
        ? kDetailDocMaxWidth
        : double.infinity;
    final ticket = ref.watch(ticketByIdProvider(widget.ticketId));
    final comments =
        ref.watch(commentsProvider(widget.ticketId)).asData?.value ??
        const <Comment>[];
    // Activity that isn't a comment (comments are rendered as bubbles below).
    final activity =
        (ref.watch(activityProvider(widget.ticketId)).asData?.value ??
                const <ActivityEvent>[])
            .where((a) => a.action != 'commented');
    final items = <_TimelineEntry>[
      for (final cm in comments) _TimelineEntry(at: cm.createdAt, comment: cm),
      for (final a in activity) _TimelineEntry(at: a.at, activity: a),
    ]..sort((x, y) => x.at.compareTo(y.at));

    ImageBytesLoader? loader() => ticket == null
        ? null
        : (url) => ref.read(syncServiceProvider).fetchTicketImage(ticket, url);

    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No comments or activity yet',
                    style: context.typography.secondary.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        context.spacing.xl3,
                        context.spacing.xl2,
                        context.spacing.xl3,
                        context.spacing.md,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final e = items[i];
                        return e.comment != null
                            ? CommentTile(e.comment!, imageLoader: loader())
                            : ActivityRow(e.activity!);
                      },
                    ),
                  ),
                ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            context.spacing.xl2,
            context.spacing.lg,
            context.spacing.xl2,
            context.spacing.xl,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: context.hairlineSide),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                children: [
                  TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    style: context.typography.body.copyWith(
                      color: c.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: c.surfaceSubtle,
                      hintText: 'Write a comment…',
                      hintStyle: context.typography.body.copyWith(
                        color: c.textTertiary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.radii.md),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.radii.md),
                        borderSide: BorderSide(color: c.border),
                      ),
                    ),
                  ),
                  SizedBox(height: context.spacing.md),
                  Row(
                    children: [
                      _NoteToggle(
                        internal: _internal,
                        onChanged: (v) => setState(() => _internal = v),
                      ),
                      const Spacer(),
                      AppButton.filled(
                        size: AppButtonSize.small,
                        onPressed: _post,
                        child: Text(_internal ? 'Save note' : 'Comment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteToggle extends StatelessWidget {
  const _NoteToggle({required this.internal, required this.onChanged});
  final bool internal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!internal),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            internal ? Icons.lock_outline : Icons.public,
            size: 14,
            color: c.textTertiary,
          ),
          SizedBox(width: context.spacing.sm),
          Text(
            internal ? 'Internal note' : 'Post to provider',
            style: context.typography.meta.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One timeline entry — either a [comment] bubble or an [activity] event.
class _TimelineEntry {
  _TimelineEntry({required this.at, this.comment, this.activity});
  final DateTime at;
  final Comment? comment;
  final ActivityEvent? activity;
}
