import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

/// Sends [text] as a message. It answers the reply draft of [draftKey]
/// (which is then cleared), else [threadRootId] in a thread.
Future<void> sendChatText(
  BuildContext context,
  WidgetRef ref, {
  required ChatComposerKey draftKey,
  required String text,
  int? threadRootId,
}) async {
  final draft = chatReplyDraftProvider(draftKey);
  final replyToId = ref.read(draft)?.serverId ?? threadRootId;
  ref.read(draft.notifier).state = null;
  final t = draftKey.chat;
  final result = await ref
      .read(chatControllerProvider)
      .send(
        t.accountId,
        t.chatGid,
        text,
        replyToId: replyToId,
        markdown: ref.read(appSettingsProvider).chatSendMarkdown,
      );
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}
