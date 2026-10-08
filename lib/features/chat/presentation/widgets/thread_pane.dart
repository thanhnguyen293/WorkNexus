import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_composer.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'chat_thread_header.dart';
import 'message_list.dart';
import 'reply_thread_panel.dart';

/// Right pane: one open chat. Pulls the newest page and marks the chat read
/// when it opens (keyed per chat by the parent, so this runs on every switch).
class ThreadPane extends ConsumerStatefulWidget {
  const ThreadPane({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  ConsumerState<ThreadPane> createState() => _ThreadPaneState();
}

class _ThreadPaneState extends ConsumerState<ThreadPane> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final controller = ref.read(chatControllerProvider);
    final t = widget.thread;
    final refreshed = await controller.refresh(t.accountId, t.chatGid);
    if (refreshed case Err(:final failure)) {
      if (mounted) showChatFailure(context, failure);
      return;
    }
    await controller.markRead(t.accountId, t.chatGid);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final chats =
        ref.watch(chatConversationsProvider(t.accountId)).asData?.value ??
        const <ChatConversation>[];
    final chat = chats.where((c) => c.gid == t.chatGid).firstOrNull;
    final users =
        ref.watch(chatUsersProvider(t.accountId)).asData?.value ??
        const <int, ChatUser>{};
    final openThread = ref.watch(openReplyThreadProvider(t));
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              ChatThreadHeader(thread: t, chat: chat, users: users),
              Expanded(
                child: MessageList(
                  thread: t,
                  showSenders: chat?.type != ChatType.one2one,
                ),
              ),
              ChatComposer(
                thread: t,
                hint: chat == null
                    ? null
                    : AppL10n.of(
                        context,
                      ).chatMessageTo(chatTitle(context, chat, users)),
              ),
            ],
          ),
        ),
        if (openThread != null)
          ReplyThreadPanel(
            key: ValueKey('thread-$openThread'),
            chat: t,
            rootId: openThread,
          ),
      ],
    );
  }
}
