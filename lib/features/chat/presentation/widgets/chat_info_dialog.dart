import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_info_panel.dart';
import 'chat_layout.dart';
import 'chat_side_panel_frame.dart';

/// Shows who the chat is with / what the group is: the info panel beside the
/// chat when there is room for it (closing a thread or other panel there),
/// else the same panel as a dialog.
void showChatInfo(
  BuildContext context,
  WidgetRef ref, {
  required ChatThreadKey thread,
  required ChatConversation chat,
  required Map<int, ChatUser> users,
}) {
  if (ChatLayoutScope.of(context).infoRoom) {
    ref.read(openReplyThreadProvider(thread).notifier).state = null;
    ref.read(chatSidePanelProvider(thread).notifier).state = null;
    return;
  }
  showDialog<void>(
    context: context,
    builder: (_) => _ChatInfoDialog(thread: thread, chat: chat, users: users),
  );
}

/// Tallest the info dialog gets, as a share of the window.
const double _kDialogHeightFactor = 0.85;

class _ChatInfoDialog extends ConsumerWidget {
  const _ChatInfoDialog({
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pinned messages and files open beside the chat: make way for them.
    ref.listen(chatSidePanelProvider(thread), (_, next) {
      if (next != null && next != ChatSidePanel.info) {
        Navigator.of(context).pop();
      }
    });
    // Not AppDialogFrame: the panel brings its own titled header and close
    // button, so the frame's would show twice. The chrome matches it.
    return Dialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: context.colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: context.colors.border),
      ),
      child: SizedBox(
        width: kChatSidePanelWidth,
        height: MediaQuery.sizeOf(context).height * _kDialogHeightFactor,
        child: ChatInfoPanel(
          thread: thread,
          chat: chat,
          users: users,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
