import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_image.dart';
import '../../../../core/widgets/rich_body_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/activity_action_parts.dart';
import '../util/image_fallback.dart';
import 'timeline_headline.dart';
import 'timeline_item.dart';

/// A comment in the merged comments/activity timeline: "author commented"
/// over the body in a card.
class CommentTile extends StatelessWidget {
  const CommentTile(
    this.comment, {
    super.key,
    this.html = false,
    this.isFirst = false,
    this.isLast = false,
    this.imageLoader,
    this.imageFallback,
  });
  final Comment comment;

  /// Whether the comment is HTML (see `isHtmlBody`).
  final bool html;
  final bool isFirst;
  final bool isLast;
  final ImageBytesLoader? imageLoader;
  final ImageFallback? imageFallback;

  @override
  Widget build(BuildContext context) {
    return TimelineItem(
      marker: TimelineAvatar(comment.authorName),
      isFirst: isFirst,
      isLast: isLast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineHeadline(
            actor: comment.authorName,
            action: AppL10n.of(context).commentedAction,
            at: comment.createdAt,
          ),
          SizedBox(height: context.spacing.sm),
          _NoteCard(
            child: RichBodyText(
              comment.body,
              html: html,
              height: 1.55,
              imageLoader: imageLoader,
              imageFallbackUrl: imageFallback?.resolveUrl,
              onOpenImage: imageFallback?.open,
            ),
          ),
        ],
      ),
    );
  }
}

/// A non-comment event in the timeline (created, assigned, resolved, …), with
/// the note and files a state change carried.
class ActivityRow extends StatelessWidget {
  const ActivityRow(
    this.event, {
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });
  final ActivityEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final note = event.detail ?? '';
    return TimelineItem(
      marker: TimelineEventIcon(activityKindOf(event.action)),
      isFirst: isFirst,
      isLast: isLast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineHeadline(
            actor: event.actor,
            action: event.action,
            at: event.at,
            compact: true,
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: s.sm),
            _NoteCard(
              child: Text(
                note,
                style: context.typography.body.copyWith(
                  color: c.textPrimary,
                  height: 1.55,
                ),
              ),
            ),
          ],
          if (event.attachments.isNotEmpty) ...[
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.xs,
              runSpacing: s.xs,
              children: [
                for (final name in event.attachments) _AttachmentChip(name),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The bordered card holding a comment body or a state change's note.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

/// A read-only chip naming a file attached in a state-change comment (e.g. a
/// reopen with an added screen recording).
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.paperclip300, size: 12, color: c.textTertiary),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.captionSm.copyWith(
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
