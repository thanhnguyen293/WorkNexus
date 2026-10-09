import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download.dart';
import 'cancel_download_button.dart';
import 'chat_image_viewer.dart';
import 'chat_labels.dart';

/// Images and videos of a chat as a grid of square thumbnails; a tap opens
/// the image viewer (browsing the chat's images) or plays the video.
class ChatMediaGrid extends StatelessWidget {
  const ChatMediaGrid({
    super.key,
    required this.accountId,
    required this.media,
    this.columns = 4,
  });

  final String accountId;

  /// Image messages and video file messages, newest first.
  final List<ChatMessage> media;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final images = [
      for (final m in media)
        if (m.content case final ImageContent image) image,
    ];
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: s.xs,
      crossAxisSpacing: s.xs,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final m in media)
          _Thumb(
            accountId: accountId,
            chatGid: m.chatGid,
            content: m.content,
            images: images,
          ),
      ],
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({
    required this.accountId,
    required this.chatGid,
    required this.content,
    required this.images,
  });

  final String accountId;
  final String chatGid;
  final MessageContent content;
  final List<ImageContent> images;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
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
    final video = content is FileContent;
    return Material(
      color: c.skeleton,
      borderRadius: BorderRadius.circular(context.radii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => switch (content) {
          final ImageContent image => ChatImageViewer.show(
            context,
            accountId: accountId,
            images: images,
            initialIndex: images.indexOf(image).clamp(0, images.length - 1),
            chatGid: chatGid,
          ),
          final FileContent file => openChatFile(
            context,
            ref,
            accountId: accountId,
            file: file,
            chatGid: chatGid,
          ),
          _ => null,
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes case Ok(:final value))
              Image.memory(value, fit: BoxFit.cover, gaplessPlayback: true),
            if (video)
              Center(
                child: Icon(
                  PhosphorIconsFill.playCircle,
                  color: c.onScrim,
                  size: context.spacing.xl5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One shared file: extension badge, name, size and date; a tap downloads
/// (when needed) and opens it.
class ChatFileRow extends ConsumerWidget {
  const ChatFileRow({super.key, required this.message, required this.file});

  final ChatMessage message;
  final FileContent file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final date = DateFormat.yMd(
      Localizations.localeOf(context).toString(),
    ).format(message.sentAt);
    final key = (accountId: message.accountId, content: file);
    final downloading = ref.watch(
      chatDownloadingProvider.select((d) => d.contains(key)),
    );
    final progress = downloading
        ? ref.watch(chatDownloadProgressProvider(key)).value ?? 0
        : null;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      borderRadius: BorderRadius.circular(context.radii.md),
      onTap: downloading
          ? null
          : () => openChatFile(
              context,
              ref,
              accountId: message.accountId,
              file: file,
              chatGid: message.chatGid,
            ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.sm),
        child: Row(
          children: [
            Container(
              width: s.xl6,
              height: s.xl6,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(context.radii.md),
              ),
              child: downloading
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
            ),
            SizedBox(width: s.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.body.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    progress == null
                        ? '${formatFileSize(file.size)} · $date'
                        : formatTransfer(file.size, progress),
                    style: context.typography.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  if (progress != null) ...[
                    SizedBox(height: s.xs),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: s.xxs,
                      borderRadius: BorderRadius.circular(context.radii.pill),
                    ),
                  ],
                ],
              ),
            ),
            if (downloading)
              CancelDownloadButton(
                onPressed: () => cancelAttachmentDownload(
                  ref,
                  accountId: message.accountId,
                  content: file,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Splits a chat's attachment messages into media (images, videos) and
/// other files.
({List<ChatMessage> media, List<ChatMessage> files}) splitChatAttachments(
  List<ChatMessage> messages,
) {
  final media = <ChatMessage>[];
  final files = <ChatMessage>[];
  for (final m in messages) {
    switch (m.content) {
      case ImageContent():
        media.add(m);
      case final FileContent f when f.fileId > 0:
        (isVideoFile(f) ? media : files).add(m);
      default:
        break;
    }
  }
  return (media: media, files: files);
}
