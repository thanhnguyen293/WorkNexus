import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_cover_decode.dart';
import 'chat_labels.dart';

/// The small square beside a quoted message (reply quote, reply draft) when
/// it carries media: an image's thumbnail, a video's preview frame with a
/// play glyph, or a file's extension. Nothing for other content.
class ReplyMediaThumb extends ConsumerWidget {
  const ReplyMediaThumb({
    super.key,
    required this.accountId,
    required this.content,
  });

  final String accountId;
  final MessageContent content;

  /// Whether [content] gets a thumb, so callers can skip the gap beside it.
  static bool shows(MessageContent content) =>
      content is ImageContent || content is FileContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final side = context.sizes.controlLg;
    final radius = BorderRadius.circular(context.radii.sm);
    final content = this.content;
    if (content is FileContent && !isVideoFile(content)) {
      return Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.accent, borderRadius: radius),
        child: Text(
          chatFileBadge(content.name),
          maxLines: 1,
          style: context.typography.captionStrong.copyWith(color: c.onAccent),
        ),
      );
    }
    if (!shows(content)) return const SizedBox.shrink();
    final bytes = switch (content) {
      ImageContent() => ref.watch(
        chatAttachmentProvider((
          accountId: accountId,
          content: content,
          thumbnail: true,
        )),
      ),
      _ => ref.watch(
        chatVideoThumbnailProvider((accountId: accountId, video: content)),
      ),
    }.value;
    final decode = coverDecodeSize(
      content,
      (side * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: side,
        child: ColoredBox(
          color: c.skeleton,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes case Ok(:final value))
                Image.memory(
                  value,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: decode.cacheWidth,
                  cacheHeight: decode.cacheHeight,
                ),
              if (content is FileContent)
                Center(
                  child: Icon(
                    LucideIcons.circlePlay300,
                    color: c.onScrim,
                    size: context.sizes.iconMd,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
