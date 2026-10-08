import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/link_preview.dart';
import '../providers/chat_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';

/// Fixed card size: the space is reserved as soon as a message has a link,
/// so the list never jumps when the preview arrives (or turns out empty).
const double _kCardHeight = 72;
const double _kCardMaxWidth = 420;

/// A preview of the web page a message links to — site, title, description
/// and a square image — at a fixed height. While loading it shows skeleton
/// lines; when the page has nothing to show, its address.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.sm);
    final state = ref.watch(chatLinkPreviewProvider(url));
    final preview = state.asData?.value;
    final image = preview?.imageUrl;
    return Padding(
      padding: EdgeInsets.only(top: s.md),
      child: InkWell(
        onTap: () => openExternally(url),
        borderRadius: radius,
        child: Container(
          height: _kCardHeight,
          constraints: const BoxConstraints(maxWidth: _kCardMaxWidth),
          decoration: BoxDecoration(
            color: ink.quoteFill,
            borderRadius: radius,
            border: Border(left: BorderSide(color: ink.quoteBar, width: 3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.lg),
                  child: state.isLoading
                      ? const _SkeletonLines()
                      : _Lines(url: url, preview: preview),
                ),
              ),
              if (image != null)
                SizedBox.square(
                  dimension: _kCardHeight,
                  child: CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Site, title, description — one line each; the address when the page has
/// no preview.
class _Lines extends StatelessWidget {
  const _Lines({required this.url, required this.preview});

  final String url;
  final LinkPreview? preview;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final p = preview;
    Text line(String text, TextStyle style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final site = context.typography.captionStrong.copyWith(color: ink.link);
    final title = context.typography.bodyStrong.copyWith(color: ink.text);
    final body = context.typography.bodySm.copyWith(
      color: ink.text.withValues(alpha: 0.75),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(p?.siteName ?? chatLinkHost(url), site),
        line(p?.title ?? url, title),
        if (p?.description case final description?) line(description, body),
      ],
    );
  }
}

class _SkeletonLines extends StatelessWidget {
  const _SkeletonLines();

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    Widget bar(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: s.lg,
        margin: EdgeInsets.symmetric(vertical: s.xs * 0.75),
        decoration: BoxDecoration(
          color: ink.text.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(context.radii.xs),
        ),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(0.3), bar(0.8), bar(0.6)],
    );
  }
}
