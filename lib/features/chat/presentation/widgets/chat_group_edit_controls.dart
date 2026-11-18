import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_group_avatar_dialog.dart';
import 'chat_name_dialog.dart';

/// A group's big picture in the info panel with, for its owner and admins,
/// a round camera badge on its corner that changes it — the edit sits on
/// what it edits instead of a text button under it.
class ChatGroupAvatarEditor extends ConsumerWidget {
  const ChatGroupAvatarEditor({
    super.key,
    required this.thread,
    required this.chat,
    required this.title,
    required this.child,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final String title;

  /// The avatar itself.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Owner and admins, as for pinning — which one-to-one chats also allow.
    if (chat.type == ChatType.one2one ||
        !ref.watch(chatCanPinProvider(thread))) {
      return child;
    }
    final c = context.colors;
    final sizes = context.sizes;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 0,
          bottom: 0,
          child: Tooltip(
            message: AppL10n.of(context).chatChangeGroupAvatar,
            child: HoverSurface(
              onTap: () => ChatGroupAvatarDialog.show(
                context,
                thread: thread,
                chat: chat,
                title: title,
              ),
              width: sizes.controlMd,
              height: sizes.controlMd,
              shape: BoxShape.circle,
              color: c.card,
              // A ring of the panel's colour cuts the badge out of the avatar.
              border: Border.all(
                color: c.background,
                width: context.borders.thick,
              ),
              semanticLabel: AppL10n.of(context).chatChangeGroupAvatar,
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.camera300,
                size: sizes.iconMd,
                color: c.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A group's name in the info panel with, for those who may rename it, a
/// small pencil after it. The pencil's width is mirrored before the name so
/// the name stays centred over the avatar.
class ChatGroupTitleEditor extends ConsumerWidget {
  const ChatGroupTitleEditor({
    super.key,
    required this.thread,
    required this.chat,
    required this.child,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;

  /// The name itself.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(chatGroupRightsProvider(thread)).rename) return child;
    final gap = context.spacing.xs;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: context.sizes.controlSm + gap),
        Flexible(child: child),
        SizedBox(width: gap),
        AppIconButton(
          icon: LucideIcons.pencil300,
          size: AppIconButtonSize.small,
          tooltip: AppL10n.of(context).chatRenameGroup,
          onPressed: () => ChatNameDialog.show(
            context,
            title: AppL10n.of(context).chatRenameGroup,
            initial: chat.name,
            hint: AppL10n.of(context).chatGroupName,
            onSave: (name) =>
                ref.read(chatGroupControllerProvider).rename(chat, name),
          ),
        ),
      ],
    );
  }
}
