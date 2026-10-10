import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download.dart';
import 'attachment_download_badge.dart';
import 'chat_image_viewer.dart';
import 'chat_upload_overlay.dart';

/// Box an inline image is fitted into (its aspect ratio is kept).
const double _kImageMaxSide = 360;

/// Placeholder size while an image loads (keeps the list from jumping).
const double _kImagePlaceholderHeight = 180;
const double _kImagePlaceholderWidth = 280;

/// An image without a bubble, rounded. Its box is sized from the width and
/// height the message carries before any byte arrives, so the list does not
/// jump. Inline it shows the server's thumbnail when there is one; until the
/// original is downloaded a badge shows its size, and a tap downloads it and
/// then opens the viewer (if the image is still on screen).
class ChatImageBody extends ConsumerWidget {
  const ChatImageBody({
    super.key,
    required this.accountId,
    required this.message,
    required this.image,
  });

  final String accountId;
  final ChatMessage message;
  final ImageContent image;

  /// Display size: the image scaled down (never up) into the max box, or a
  /// fixed placeholder when the sender did not record a size.
  Size get _size {
    final w = image.width;
    final h = image.height;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return const Size(_kImagePlaceholderWidth, _kImagePlaceholderHeight);
    }
    final scale = [
      1.0,
      _kImageMaxSide / w,
      _kImageMaxSide / h,
    ].reduce((a, b) => a < b ? a : b);
    return Size(w * scale, h * scale);
  }

  /// The chat's loaded images, for previous/next in the viewer.
  void _openViewer(BuildContext context, WidgetRef ref) {
    final messages =
        ref
            .read(
              chatMessagesProvider((
                accountId: accountId,
                chatGid: message.chatGid,
              )),
            )
            .value ??
        const <ChatMessage>[];
    final images = [
      for (final m in messages)
        if (!m.deleted && m.content is ImageContent) m.content as ImageContent,
    ];
    final index = images.indexOf(image);
    ChatImageViewer.show(
      context,
      accountId: accountId,
      images: index < 0 ? [image] : images,
      initialIndex: index < 0 ? 0 : index,
      chatGid: message.chatGid,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final radius = BorderRadius.circular(context.radii.lg);
    final size = _size;
    // An own image not uploaded yet has no file on the server: it shows the
    // picked bytes, with the upload's progress over them while it is sent.
    final local = image.fileId == 0 && message.sendState != SendState.sent
        ? ref.watch(chatPendingUploadBytesProvider(message.gid))
        : null;
    if (local != null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                local,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth:
                    (size.width * MediaQuery.devicePixelRatioOf(context))
                        .round(),
              ),
              if (message.sendState == SendState.pending)
                ChatUploadOverlay(messageGid: message.gid),
            ],
          ),
        ),
      );
    }
    final bytes = ref.watch(
      chatAttachmentProvider((
        accountId: accountId,
        content: image,
        thumbnail: true,
      )),
    );
    final Widget child = switch (bytes) {
      // Decoded at display size: full-size decodes of every image passing
      // by make fast scrolling stutter.
      AsyncData(value: Ok(:final value)) => Image.memory(
        value,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: (size.width * MediaQuery.devicePixelRatioOf(context))
            .round(),
      ),
      AsyncData(value: Err()) || AsyncError() => ColoredBox(
        color: c.surface,
        child: Center(
          child: Icon(PhosphorIconsLight.imageBroken, color: c.textTertiary),
        ),
      ),
      _ => ColoredBox(color: c.skeleton),
    };
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      borderRadius: radius,
      onTap: () => openAttachment(
        context,
        ref,
        accountId: accountId,
        content: image,
        open: () async => _openViewer(context, ref),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              // Without a server thumbnail the inline image is the original.
              if (image.hasThumb)
                Positioned(
                  left: context.spacing.md,
                  bottom: context.spacing.md,
                  child: AttachmentDownloadBadge(
                    accountId: accountId,
                    content: image,
                    size: image.size,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
