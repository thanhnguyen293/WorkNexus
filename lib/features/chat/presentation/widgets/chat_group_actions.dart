import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

/// At the bottom of a group's info panel: its owner dismisses the group for
/// everyone, anyone else leaves it — after asking. Either way the group is
/// gone from the chat list, so it is closed too.
class ChatGroupExitButton extends ConsumerWidget {
  const ChatGroupExitButton({
    super.key,
    required this.thread,
    required this.chat,
    required this.title,
    this.onExited,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final String title;

  /// Closes the info panel where it is shown as a dialog.
  final VoidCallback? onExited;

  Future<void> _exit(
    BuildContext context,
    WidgetRef ref, {
    required bool dismiss,
  }) async {
    final l = AppL10n.of(context);
    final label = dismiss ? l.chatDismissGroup : l.chatLeaveGroup;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: label,
      message: dismiss
          ? l.chatDismissGroupConfirm(title)
          : l.chatLeaveGroupConfirm(title),
      confirmLabel: label,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final controller = ref.read(chatGroupControllerProvider);
    final self = ref.read(chatSelfAccountProvider(thread.accountId));
    final result = dismiss
        ? await controller.dismiss(chat, selfAccount: self)
        : await controller.leave(chat, selfAccount: self);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showChatSnack(
          context,
          dismiss ? l.chatGroupDismissed : l.chatLeftGroup,
        );
        // It has left the chat list; leave it open and it would linger.
        ref.read(selectedChatGidProvider(thread.accountId).notifier).state =
            null;
        onExited?.call();
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final rights = ref.watch(chatGroupRightsProvider(thread));
    if (!rights.dismiss && !rights.leave) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: AppButton.error(
        size: AppButtonSize.small,
        icon: rights.dismiss ? LucideIcons.trash2300 : LucideIcons.logOut300,
        onPressed: () => _exit(context, ref, dismiss: rights.dismiss),
        child: Text(rights.dismiss ? l.chatDismissGroup : l.chatLeaveGroup),
      ),
    );
  }
}
