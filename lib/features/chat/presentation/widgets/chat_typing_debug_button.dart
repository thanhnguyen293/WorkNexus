import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/value_objects/chat_typing_signal.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_typing_providers.dart';

/// Debug builds only: pretends someone in the chat started typing, to see the
/// typing UI without a second account. Each click adds one more person (a
/// one-to-one chat has only its peer); it lapses like a real signal.
class ChatTypingDebugButton extends ConsumerWidget {
  const ChatTypingDebugButton({
    super.key,
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  void _simulate(WidgetRef ref) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppIconButton(
    icon: LucideIcons.keyboard300,
    tooltip: AppL10n.of(context).chatDebugSimulateTyping,
    onPressed: () => _simulate(ref),
  );
}
