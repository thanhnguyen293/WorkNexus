import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download_badge.dart';
import 'chat_labels.dart';

/// A video as a 16:9 frame: its preview image (when one can be made), a play
/// button, and the name and size along the bottom edge.
class ChatVideoTile extends ConsumerWidget {
  const ChatVideoTile({
    super.key,
    required this.accountId,
    required this.file,
    required this.onTap,
  });

  final String accountId;
  final FileContent file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final frame = switch (ref.watch(
      chatVideoThumbnailProvider((accountId: accountId, video: file)),
    )) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    final radius = BorderRadius.circular(context.radii.lg);
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: radius,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: c.skeleton),
                  if (frame != null) Image.memory(frame, fit: BoxFit.cover),
                  Positioned(
                    left: s.md,
                    bottom: s.md,
                    child: AttachmentDownloadBadge(
                      accountId: accountId,
                      content: file,
                      size: file.size,
                    ),
                  ),
                  Center(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: c.surface,
                        shape: CircleBorder(side: BorderSide(color: c.border)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(s.md),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: s.xl6 * 0.75,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: s.sm, left: s.xs, right: s.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: s.md),
                Text(
                  formatFileSize(file.size),
                  style: context.typography.caption.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
