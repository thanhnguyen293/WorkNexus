import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/wallpaper_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'chat_style.dart';
import 'chat_wallpaper.dart';
import 'mention_text.dart';

/// A server notice about the chat ("@A invited @B to the group"), centered
/// like a date separator rather than drawn as a message from its sender:
/// a bell, the time and the text with its mentions.
class ChatNotice extends ConsumerWidget {
  const ChatNotice({super.key, required this.style, required this.message});

  final ChatStyle style;
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = style.palette;
    final s = context.spacing;
    final onPicture = ref.watch(
      shownChatWallpaperProvider.select(chatWallpaperIsPicture),
    );
    // Same look as the style's separators: its own pill, a dark scrim pill
    // over a picture background, or plain text.
    final ownPill = style.separator == ChatSeparatorStyle.pill;
    final scrimPill = onPicture && !ownPill;
    final filled = ownPill || scrimPill;
    final ink = scrimPill ? context.colors.onScrim : p.separatorText;
    final caption = context.typography.captionStrong;
    final content = message.content;
    final text = content is TextContent
        ? chatNoticeText(content)
        : chatPreview(context, message);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: s.xxs),
          child: Icon(
            LucideIcons.bell300,
            size: context.sizes.iconSm,
            color: filled ? ink : p.incomingLink,
          ),
        ),
        SizedBox(width: s.sm),
        Text(
          formatTime(message.sentAt),
          style: caption.copyWith(color: ink, height: 1.45),
        ),
        SizedBox(width: s.sm),
        Flexible(
          child: ChatBubbleTheme(
            ink: ChatBubbleInk(
              text: ink,
              meta: ink,
              // On a pill the names stand out by weight; plain text over
              // the chat background can take the link colour.
              link: filled ? ink : p.incomingLink,
              quoteBar: ink,
              quoteFill: ink,
              tileFill: ink,
              fontSize: caption.fontSize ?? style.fontSize,
            ),
            child: MentionText(text, accountId: message.accountId),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.xs),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: style.maxWidth),
          // Selectable text fills its width; size the notice to its words.
          child: IntrinsicWidth(
            child: filled
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: scrimPill
                          ? context.colors.scrim.withValues(alpha: 0.45)
                          : p.separatorFill,
                      borderRadius: BorderRadius.circular(context.radii.lg),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: s.xl,
                        vertical: s.xs,
                      ),
                      child: row,
                    ),
                  )
                : row,
          ),
        ),
      ),
    );
  }
}
