import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download.dart';
import 'chat_bubble_theme.dart';
import 'chat_file_action_button.dart';
import 'chat_file_badge.dart';
import 'chat_labels.dart';
import 'chat_upload_overlay.dart';
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
    chatGid: widget.message.chatGid,
  );

  @override
  Widget build(BuildContext context) {
    if (_sent && isVideoFile(widget.file)) {
      return ChatVideoTile(
        accountId: widget.accountId,
        file: widget.file,
        chatGid: widget.message.chatGid,
        messageGid: widget.message.gid,
        onFullScreen: _open,
      );
    }
    final uploading =
        widget.message.sendState == SendState.pending &&
        widget.file.fileId == 0;
    // An own video not uploaded yet is still drawn as a video (from the
    // picked bytes) rather than as a file tile.
    if (!_sent &&
        widget.file.fileId == 0 &&
        widget.message.sendState != SendState.sent &&
        isVideoFile(widget.file)) {
      return ChatVideoTile(
        accountId: widget.accountId,
        file: widget.file,
        uploadGid: widget.message.gid,
        uploading: uploading,
      );
    }
    final downloading = ref.watch(
      chatDownloadingProvider.select((d) => d.contains(_key)),
    );
    final cached = _sent
        ? ref.watch(chatAttachmentCachedProvider(_key)).value
        : null;
    return _FileTile(
      file: widget.file,
      opening: downloading,
      onDevice: downloading ? null : cached,
      onReveal: _sent && !downloading && cached == true
          ? () => revealAttachment(
              context,
              ref,
              accountId: widget.accountId,
              content: widget.file,
            )
          : null,
      onSave: _sent && !downloading
          ? () => saveAttachment(
              context,
              ref,
              accountId: widget.accountId,
              content: widget.file,
              name: widget.file.name,
            )
          : null,
      onTap: _sent && !downloading ? _open : null,
      cancelTooltip: uploading ? AppL10n.of(context).chatCancelUpload : null,
      onCancel: uploading
          ? () => cancelChatUpload(
              context,
              ref,
              accountId: widget.accountId,
              messageGid: widget.message.gid,
            )
          : downloading
          ? () => cancelAttachmentDownload(
              ref,
              accountId: widget.accountId,
              content: widget.file,
            )
          : null,
      progress: uploading
          ? ref.watch(chatUploadProgressProvider(widget.message.gid)).value ?? 0
          : downloading
          ? ref.watch(chatDownloadProgressProvider(_key)).value
          : null,
    );
  }
}

/// Extension badge, name, size and where the file is (this device or only
/// the server); while it uploads or downloads the badge turns into a ring
/// filling with [progress] (0–1). A sent file has "save as" on the right,
/// and "show in folder" once it is on this device.
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.opening,
    required this.onTap,
    this.onDevice,
    this.progress,
    this.onCancel,
    this.cancelTooltip,
    this.onReveal,
    this.onSave,
  });

  final FileContent file;
  final bool opening;
  final VoidCallback? onTap;

  /// Whether the file is downloaded; null while unknown or moving.
  final bool? onDevice;
  final double? progress;

  /// Set while it downloads or uploads: hovering the badge shows a ✕ that
  /// stops it.
  final VoidCallback? onCancel;

  /// The stop button's tooltip; defaults to "Cancel download".
  final String? cancelTooltip;

  /// Shows the file in the system file manager; set once it is on this
  /// device.
  final VoidCallback? onReveal;

  /// Saves a copy where the user picks (downloading it first).
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final meta = ChatBubbleTheme.of(context).meta;
    final metaStyle = context.typography.caption.copyWith(color: meta);
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatFileBadge(
              fileName: file.name,
              busy: opening || progress != null,
              progress: progress,
              onCancel: onCancel,
              cancelTooltip: cancelTooltip,
            ),
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
                  SizedBox(height: s.xxs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTransfer(file.size, progress),
                        style: metaStyle,
                      ),
                      if (onDevice case final here?) ...[
                        SizedBox(width: s.md),
                        Icon(
                          here
                              ? LucideIcons.circleCheck300
                              : LucideIcons.cloudCheck300,
                          size: s.xl2,
                          color: meta,
                        ),
                        SizedBox(width: s.xs),
                        Flexible(
                          child: Text(
                            here ? l.chatFileOnDevice : l.chatFileOnCloud,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onReveal case final reveal?) ...[
              SizedBox(width: s.lg),
              ChatFileActionButton(
                icon: LucideIcons.folder300,
                tooltip: l.chatShowInFolder,
                onPressed: reveal,
              ),
            ],
            if (onSave case final save?) ...[
              SizedBox(width: s.md),
              ChatFileActionButton(
                icon: LucideIcons.download300,
                tooltip: l.chatSaveAs,
                onPressed: save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
