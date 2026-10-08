import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'chat_video_dialog.dart';

/// A file message. A sent video is a preview frame with a play button that
/// plays in-app; any other file is a tile that downloads and opens with the
/// system's default app. While an own file uploads, the tile shows progress.
class FileBody extends ConsumerStatefulWidget {
  const FileBody({
    super.key,
    required this.accountId,
    required this.message,
    required this.file,
  });

  final String accountId;
  final ChatMessage message;
  final FileContent file;

  @override
  ConsumerState<FileBody> createState() => _FileBodyState();
}

class _FileBodyState extends ConsumerState<FileBody> {
  bool _opening = false;

  bool get _sent => widget.file.fileId > 0 && !widget.message.deleted;

  Future<void> _open() async {
    if (isVideoFile(widget.file)) {
      await ChatVideoDialog.show(
        context,
        accountId: widget.accountId,
        video: widget.file,
      );
      return;
    }
    setState(() => _opening = true);
    final path = await ref
        .read(chatControllerProvider)
        .attachmentFile(widget.accountId, widget.file);
    if (!mounted) return;
    setState(() => _opening = false);
    switch (path) {
      case Ok(:final value):
        await openExternally(value);
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent && isVideoFile(widget.file)) {
      return _VideoTile(
        accountId: widget.accountId,
        file: widget.file,
        onTap: _open,
      );
    }
    final uploading =
        widget.message.sendState == SendState.pending &&
        widget.file.fileId == 0;
    return _FileTile(
      file: widget.file,
      opening: _opening,
      onTap: _sent && !_opening ? _open : null,
      progress: uploading
          ? ref
                    .watch(chatUploadProgressProvider(widget.message.gid))
                    .asData
                    ?.value ??
                0
          : null,
    );
  }
}

/// Extension badge, name and size; [progress] (0–1) while uploading.
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.opening,
    required this.onTap,
    this.progress,
  });

  final FileContent file;
  final bool opening;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final badge = Container(
      width: s.xl6,
      height: s.xl6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: opening
          ? SizedBox.square(
              dimension: s.xl3,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.onAccent,
              ),
            )
          : Text(
              chatFileBadge(file.name),
              style: context.typography.captionStrong.copyWith(
                color: c.onAccent,
              ),
            ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                badge,
                SizedBox(width: s.lg),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.bodyStrong.copyWith(
                          color: ChatBubbleTheme.of(context).text,
                        ),
                      ),
                      Text(
                        formatFileSize(file.size),
                        style: context.typography.caption.copyWith(
                          color: ChatBubbleTheme.of(context).meta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (progress case final value?) ...[
              SizedBox(height: s.md),
              LinearProgressIndicator(
                value: value,
                minHeight: s.xs,
                borderRadius: BorderRadius.circular(context.radii.pill),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A video as a 16:9 frame: its preview image (when one can be made), a play
/// button, and the name and size along the bottom edge.
class _VideoTile extends ConsumerWidget {
  const _VideoTile({
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
