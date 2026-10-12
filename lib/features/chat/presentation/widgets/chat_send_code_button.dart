import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_toolbar.dart';
import 'chat_snack.dart';
import 'send_code_dialog.dart';

/// The composer's "send code" tool: asks for a snippet and sends it. Like a
/// text message, it answers the reply draft of [draftKey] (which is then
/// cleared), else [threadRootId] in a thread.
class ChatSendCodeButton extends ConsumerWidget {
  const ChatSendCodeButton({
    super.key,
    required this.draftKey,
    this.threadRootId,
  });

  final ChatComposerKey draftKey;
  final int? threadRootId;

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final code = await SendCodeDialog.show(context);
    if (code == null || !context.mounted) return;
    final draft = chatReplyDraftProvider(draftKey);
    final replyToId = ref.read(draft)?.serverId ?? threadRootId;
    ref.read(draft.notifier).state = null;
    final t = draftKey.chat;
    final result = await ref
        .read(chatControllerProvider)
        .sendCode(
          t.accountId,
          t.chatGid,
          code: code.code,
          language: code.language,
          name: code.name,
          replyToId: replyToId,
        );
    if (result case Err(:final failure)) {
      if (context.mounted) showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChatComposerToolButton(
    icon: LucideIcons.codeXml300,
    tooltip: AppL10n.of(context).chatSendCode,
    onPressed: () => _send(context, ref),
  );
}
