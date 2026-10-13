import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/value_objects/chat_typing_signal.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_typing_providers.dart';

/// Debug builds only, in the title bar while a chat is open: pretends someone
/// in it started typing, to see the typing UI without a second account. Each
/// click adds one more person (a one-to-one chat has only its peer); it
/// lapses like a real signal. Release builds get nothing (the tooltip is a
/// developer string, not localised, for that reason).
class ChatTypingDebugButton extends ConsumerWidget {
  const ChatTypingDebugButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode || !ref.watch(chatOpenProvider)) {
      return const SizedBox.shrink();
    }
    final accountId = ref.watch(selectedChatAccountIdProvider);
    final chatGid = accountId == null
        ? null
        : ref.watch(selectedChatGidProvider(accountId));
    if (accountId == null || chatGid == null) return const SizedBox.shrink();
    final s = context.spacing;
    return Tooltip(
      message: 'Debug: simulate someone typing in this chat',
      child: HoverSurface(
        onTap: () => _simulate(ref, (accountId: accountId, chatGid: chatGid)),
        width: s.xl5 + s.xs,
        height: s.xl5 + s.xs,
        alignment: Alignment.center,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Icon(
          LucideIcons.keyboard300,
          size: s.xl3,
          color: context.colors.warning,
        ),
      ),
    );
  }

  void _simulate(WidgetRef ref, ChatThreadKey thread) {
    final chat = ref
        .read(chatConversationsProvider(thread.accountId))
        .asData
        ?.value
        .where((c) => c.gid == thread.chatGid)
        .firstOrNull;
    if (chat == null) return;
    final users =
        ref.read(chatUsersProvider(thread.accountId)).asData?.value ?? const {};
    final self = ref.read(chatSelfUserIdProvider(thread.accountId)).value;
    final typing = ref.read(chatTypingUsersProvider(thread));
    final candidates = chat.type == ChatType.one2one
        ? [?chat.peerUserId]
        : (users.keys.toList()..sort());
    // User 0 is the bot.
    final next =
        candidates
            .where((id) => id != 0 && id != self && !typing.contains(id))
            .firstOrNull ??
        typing.firstOrNull;
    if (next == null) return;
    ref
        .read(chatTypingProvider(thread.accountId).notifier)
        .simulate(
          ChatTypingSignal(chatGid: thread.chatGid, userId: next, typing: true),
        );
  }
}
