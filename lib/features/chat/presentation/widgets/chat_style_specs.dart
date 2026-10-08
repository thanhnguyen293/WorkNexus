import 'package:flutter/material.dart';

import '../../../../core/settings/chat_appearance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/chat_style_palette.dart';
import 'bubble_tail.dart';
import 'chat_avatar.dart';
import 'chat_style.dart';

/// Layout metrics and colours of each [ChatAppearance], modelled on the real
/// apps (Telegram from its open-source palette and styles).
ChatStyle chatStyleSpec(
  ChatAppearance appearance,
  BuildContext context, {
  required bool dark,
}) {
  final r = context.radii;
  return switch (appearance) {
    ChatAppearance.worknexus => ChatStyle(
      palette: ChatStylePalette.fromTheme(context.colors),
      avatar: ChatAvatarPlacement.firstOfRun,
      avatarShape: ChatAvatarShape.circle,
      avatarSize: 32,
      ownAvatar: false,
      avatarInDirectChats: true,
      name: ChatNamePlacement.aboveBubble,
      time: ChatTimePlacement.belowContent,
      quote: ChatQuotePlacement.inside,
      separator: ChatSeparatorStyle.hairline,
      separatorGap: null,
      radius: r.lg,
      joinRadius: r.xs,
      tail: null,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      maxWidth: 560,
      runGap: 2,
      groupGap: 16,
      fontSize: 13,
      ticks: false,
    ),
    ChatAppearance.telegram => ChatStyle(
      palette: dark
          ? ChatStylePalette.telegramNight
          : ChatStylePalette.telegramDay,
      avatar: ChatAvatarPlacement.lastOfRun,
      avatarShape: ChatAvatarShape.circle,
      avatarSize: 33,
      ownAvatar: false,
      avatarInDirectChats: false,
      name: ChatNamePlacement.insideBubble,
      time: ChatTimePlacement.insideEnd,
      quote: ChatQuotePlacement.inside,
      separator: ChatSeparatorStyle.pill,
      separatorGap: null,
      radius: 16,
      joinRadius: 6,
      tail: BubbleTailKind.curlBottom,
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 7),
      maxWidth: 480,
      runGap: 2,
      groupGap: 10,
      fontSize: 13.5,
      ticks: true,
    ),
    ChatAppearance.zalo => ChatStyle(
      palette: dark ? ChatStylePalette.zaloDark : ChatStylePalette.zaloLight,
      avatar: ChatAvatarPlacement.firstOfRun,
      avatarShape: ChatAvatarShape.circle,
      avatarSize: 40,
      ownAvatar: false,
      avatarInDirectChats: true,
      name: ChatNamePlacement.insideBubble,
      time: ChatTimePlacement.belowContent,
      quote: ChatQuotePlacement.inside,
      separator: ChatSeparatorStyle.pill,
      separatorGap: null,
      radius: 8,
      joinRadius: 8,
      tail: null,
      padding: const EdgeInsets.all(12),
      maxWidth: 600,
      runGap: 4,
      groupGap: 14,
      fontSize: 14.5,
      ticks: false,
    ),
    ChatAppearance.messenger => ChatStyle(
      palette: dark
          ? ChatStylePalette.messengerDark
          : ChatStylePalette.messengerLight,
      avatar: ChatAvatarPlacement.lastOfRun,
      avatarShape: ChatAvatarShape.circle,
      avatarSize: 28,
      ownAvatar: false,
      avatarInDirectChats: true,
      name: ChatNamePlacement.aboveBubble,
      time: ChatTimePlacement.separators,
      quote: ChatQuotePlacement.above,
      separator: ChatSeparatorStyle.plain,
      separatorGap: const Duration(minutes: 15),
      radius: 18,
      joinRadius: 4,
      tail: null,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      maxWidth: 520,
      runGap: 2,
      groupGap: 12,
      fontSize: 14.5,
      ticks: false,
    ),
    ChatAppearance.wechat => ChatStyle(
      palette: dark
          ? ChatStylePalette.wechatDark
          : ChatStylePalette.wechatLight,
      avatar: ChatAvatarPlacement.everyMessage,
      avatarShape: ChatAvatarShape.roundedSquare,
      avatarSize: 36,
      ownAvatar: true,
      avatarInDirectChats: true,
      name: ChatNamePlacement.aboveBubble,
      time: ChatTimePlacement.separators,
      quote: ChatQuotePlacement.below,
      separator: ChatSeparatorStyle.plain,
      separatorGap: const Duration(minutes: 5),
      radius: 4,
      joinRadius: 4,
      tail: BubbleTailKind.triangleTop,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      maxWidth: 520,
      runGap: 16,
      groupGap: 16,
      fontSize: 14,
      ticks: false,
    ),
    ChatAppearance.tbchat => ChatStyle(
      palette: dark
          ? ChatStylePalette.tbchatDark
          : ChatStylePalette.tbchatLight,
      avatar: ChatAvatarPlacement.firstOfRun,
      avatarShape: ChatAvatarShape.circle,
      avatarSize: 40,
      ownAvatar: false,
      avatarInDirectChats: false,
      name: ChatNamePlacement.aboveBubble,
      time: ChatTimePlacement.insideEnd,
      quote: ChatQuotePlacement.inside,
      separator: ChatSeparatorStyle.pill,
      separatorGap: null,
      radius: 12,
      joinRadius: 12,
      tail: BubbleTailKind.curlBottom,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      maxWidth: 560,
      runGap: 4,
      groupGap: 16,
      fontSize: 15,
      ticks: false,
    ),
  };
}
