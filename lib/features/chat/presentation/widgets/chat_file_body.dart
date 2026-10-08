import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'chat_video_tile.dart';

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
  bool get _sent => widget.file.fileId > 0 && !widget.message.deleted;

  ChatAttachmentKey get _key =>
      (accountId: widget.accountId, content: widget.file);

  Future<void> _open() => openChatFile(
    context,
    ref,
    accountId: widget.accountId,
    file: widget.file,
  );

  @override
  Widget build(BuildContext context) {
    if (_sent && isVideoFile(widget.file)) {
      return ChatVideoTile(
        accountId: widget.accountId,
        file: widget.file,
        onTap: _open,
      );
    }
    final uploading =
        widget.message.sendState == SendState.pending &&
        widget.file.fileId == 0;
    final downloading = ref.watch(
      chatDownloadingProvider.select((d) => d.contains(_key)),
    );
    final cached = _sent
        ? ref.watch(chatAttachmentCachedProvider(_key)).value
        : null;
    return _FileTile(
      file: widget.file,
      opening: downloading,
      needsDownload: cached == false && !downloading,
      onTap: _sent && !downloading ? _open : null,
      progress: uploading
          ? ref.watch(chatUploadProgressProvider(widget.message.gid)).value ?? 0
          : downloading
          ? ref.watch(chatDownloadProgressProvider(_key)).value
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
    this.needsDownload = false,
    this.progress,
  });

  final FileContent file;
  final bool opening;

  /// Not downloaded yet: a download arrow next to the size.
  final bool needsDownload;
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (needsDownload)
                            Icon(
                              Icons.download_rounded,
                              size: s.xl2,
                              color: ChatBubbleTheme.of(context).meta,
                            ),
                          Text(
                            formatFileSize(file.size),
                            style: context.typography.caption.copyWith(
                              color: ChatBubbleTheme.of(context).meta,
                            ),
                          ),
                        ],
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
