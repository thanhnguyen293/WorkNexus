import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../providers/chat_providers.dart';
import 'attachment_preview_dialog.dart';
import 'chat_attachments.dart';
import 'chat_snack.dart';

/// Shows [files] in the send preview and sends what the user kept — picked,
/// pasted or dropped alike. They answer the reply draft of [draftKey] (which
/// is then cleared), else [threadRootId] in a thread.
Future<void> previewAndSendChatFiles(
  BuildContext context,
  WidgetRef ref, {
  required ChatComposerKey draftKey,
  required List<ChatAttachment> files,
  int? threadRootId,
}) async {
  final chosen = await AttachmentPreviewDialog.show(context, files);
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  final draft = chatReplyDraftProvider(draftKey);
  final replyToId = ref.read(draft)?.serverId ?? threadRootId;
  ref.read(draft.notifier).state = null;
  final t = draftKey.chat;
  final controller = ref.read(chatControllerProvider);
  for (final f in chosen) {
    final result = await controller.sendFile(
      t.accountId,
      t.chatGid,
      name: f.name,
      bytes: f.bytes,
      replyToId: replyToId,
    );
    if (result case Err(:final failure)) {
      if (context.mounted) showChatFailure(context, failure);
    }
  }
}
