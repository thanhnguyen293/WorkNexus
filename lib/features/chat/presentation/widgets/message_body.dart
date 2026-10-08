import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_file_body.dart';
import 'chat_labels.dart';
import 'link_preview_card.dart';
import 'mention_text.dart';

/// Placeholder height while an image loads (keeps the list from jumping).
const double _kImagePlaceholderHeight = 180;
const double _kImagePlaceholderWidth = 280;

/// The content of a message, by content type.
class MessageBody extends StatelessWidget {
  const MessageBody({
    super.key,
    required this.accountId,
    required this.message,
  });

  final String accountId;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final l = AppL10n.of(context);
    if (message.deleted) {
      return Text(
        l.chatRetracted,
        style: context.typography.body.copyWith(
          color: ink.meta,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return switch (message.content) {
      TextContent(:final text, :final markdown) => _TextBody(
        text: text,
        markdown: markdown || chatLooksLikeMarkdown(text),
      ),
      final ImageContent image => _ImageBody(
        accountId: accountId,
        image: image,
      ),
      final FileContent file => FileBody(
        accountId: accountId,
        message: message,
        file: file,
      ),
      LinkContent(:final url, :final title) => _LinkCard(
        url: url,
        title: title,
      ),
      UnsupportedContent(:final contentType) => Text(
        l.chatUnsupportedMessage(contentType),
        style: context.typography.bodySm.copyWith(
          color: ink.meta,
          fontStyle: FontStyle.italic,
        ),
      ),
    };
  }
}

/// Message text — Markdown or plain with mentions and links — followed by a
/// preview of the first web page it links to.
class _TextBody extends StatelessWidget {
  const _TextBody({required this.text, required this.markdown});

  final String text;
  final bool markdown;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final url = chatFirstUrl(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (markdown)
          MarkdownText(
            text,
            fontSize: ink.fontSize,
            height: 1.5,
            color: ink.text,
            linkColor: ink.link,
          )
        else
          MentionText(text),
        if (url != null) LinkPreviewCard(url: url),
      ],
    );
  }
}

/// A shared link: icon tile, title and the site it points to.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.url, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    return InkWell(
      onTap: () => openExternally(url),
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: s.xl6,
            height: s.xl6,
            decoration: BoxDecoration(
              color: ink.tileFill,
              borderRadius: BorderRadius.circular(context.radii.md),
            ),
            child: Icon(Icons.link_rounded, color: ink.link),
          ),
          SizedBox(width: s.lg),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: ink.link,
                  ),
                ),
                Text(
                  chatLinkHost(url),
                  style: context.typography.caption.copyWith(color: ink.meta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Box an inline image is fitted into (its aspect ratio is kept).
const double _kImageMaxSide = 360;

/// An image without a bubble, rounded; tap to enlarge. Its box is sized from
/// the width/height the message carries before any byte arrives, so the list
/// does not jump when it loads. Inline it shows the server's thumbnail when
/// there is one; the enlarged view loads the original.
class _ImageBody extends ConsumerWidget {
  const _ImageBody({required this.accountId, required this.image});

  final String accountId;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final radius = BorderRadius.circular(context.radii.lg);
    final size = _size;
    final bytes = ref.watch(
      chatAttachmentProvider((
        accountId: accountId,
        content: image,
        thumbnail: true,
      )),
    );
    final Widget child = switch (bytes) {
      AsyncData(value: Ok(:final value)) => Image.memory(
        value,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
      AsyncData(value: Err()) || AsyncError() => ColoredBox(
        color: c.surface,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: c.textTertiary),
        ),
      ),
      _ => ColoredBox(color: c.skeleton),
    };
    return InkWell(
      borderRadius: radius,
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _FullImageDialog(accountId: accountId, image: image),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    );
  }
}

/// The original image, zoomable.
class _FullImageDialog extends ConsumerWidget {
  const _FullImageDialog({required this.accountId, required this.image});

  final String accountId;
  final ImageContent image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(
      chatAttachmentProvider((
        accountId: accountId,
        content: image,
        thumbnail: false,
      )),
    );
    return Dialog(
      backgroundColor: context.colors.surface,
      child: switch (bytes) {
        AsyncData(value: Ok(:final value)) => InteractiveViewer(
          child: Image.memory(value),
        ),
        AsyncData(value: Err()) || AsyncError() => Padding(
          padding: EdgeInsets.all(context.spacing.xl4),
          child: Text(AppL10n.of(context).chatAttachmentFailed),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      },
    );
  }
}
