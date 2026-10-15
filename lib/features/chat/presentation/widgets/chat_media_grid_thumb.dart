import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download.dart';
import 'chat_cover_decode.dart';
import 'chat_image_viewer.dart';

/// One square tile of the chat's media grid: an image's thumbnail or a
/// video's preview frame; a tap opens the viewer (browsing [images]) or
/// plays the video.
class ChatMediaGridThumb extends ConsumerWidget {
  const ChatMediaGridThumb({
    super.key,
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
              // Decoded at the tile's size, not the photo's.
              LayoutBuilder(
                builder: (context, constraints) {
                  final decode = coverDecodeSize(
                    content,
                    (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                  );
                  return Image.memory(
                    value,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: decode.cacheWidth,
                    cacheHeight: decode.cacheHeight,
                  );
                },
              ),
            if (video)
              Center(
                child: Icon(
                  LucideIcons.circlePlay300,
                  color: c.onScrim,
                  size: context.sizes.iconXl,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
