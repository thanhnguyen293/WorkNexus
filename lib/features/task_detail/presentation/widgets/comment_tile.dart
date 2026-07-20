import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../util/image_fallback.dart';

/// A single comment bubble in the merged comments/activity timeline.
class CommentTile extends ConsumerWidget {
  const CommentTile(
    this.comment, {
    super.key,
    this.imageLoader,
    this.imageFallback,
  });
  final Comment comment;
  final ImageBytesLoader? imageLoader;
  final ImageFallback? imageFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final internal = comment.origin == CommentOrigin.internalNote;
    return Container(
      margin: EdgeInsets.only(bottom: context.spacing.lg),
      padding: EdgeInsets.all(context.spacing.lg),
      decoration: BoxDecoration(
        color: internal ? c.mixT(c.warning, 0.08) : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(
          color: internal ? c.mixT(c.warning, 0.30) : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment.authorName,
                style: context.typography.monoStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(width: context.spacing.md),
              if (internal)
                Text(
                  'note',
                  style: context.typography.captionSm.copyWith(
                    color: c.warning,
                  ),
                ),
              const Spacer(),
              Text(
                formatWhen(
                  context,
                  comment.createdAt,
                  format: ref.watch(
                    appSettingsProvider.select((s) => s.dateFormat),
                  ),
                ),
                style: context.typography.monoXs.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          MarkdownText(
            comment.body,
            fontSize: 12.5,
            height: 1.5,
            imageLoader: imageLoader,
            imageFallbackUrl: imageFallback?.resolveUrl,
            onOpenImage: imageFallback?.open,
          ),
        ],
      ),
    );
  }
}

/// A compact non-comment activity line in the merged timeline.
class ActivityRow extends ConsumerWidget {
  const ActivityRow(this.event, {super.key});
  final ActivityEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: context.spacing.xs,
              left: context.spacing.xxs,
            ),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: c.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: context.spacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: context.typography.bodySm.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: event.actor,
                        style: context.typography.bodySmStrong.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      TextSpan(text: ' ${event.action}'),
                    ],
                  ),
                ),
                if (event.detail != null && event.detail!.isNotEmpty) ...[
                  SizedBox(height: context.spacing.sm),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.lg,
                      vertical: context.spacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceSubtle,
                      borderRadius: BorderRadius.circular(context.radii.sm),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      event.detail!,
                      style: context.typography.bodySm.copyWith(
                        color: c.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                if (event.attachments.isNotEmpty) ...[
                  SizedBox(height: context.spacing.sm),
                  Wrap(
                    spacing: context.spacing.xs,
                    runSpacing: context.spacing.xs,
                    children: [
                      for (final name in event.attachments)
                        _AttachmentChip(name),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: context.spacing.md),
          Text(
            formatWhen(
              context,
              event.at,
              format: ref.watch(
                appSettingsProvider.select((s) => s.dateFormat),
              ),
            ),
            style: context.typography.monoXs.copyWith(color: c.textTertiary),
          ),
        ],
      ),
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
          Icon(Icons.attach_file, size: 12, color: c.textTertiary),
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
