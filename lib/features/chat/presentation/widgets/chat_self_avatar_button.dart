import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/open_account_profile.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_self_menu.dart';
import 'chat_user_profile_dialog.dart';

/// The signed-in user's own avatar at the top of the chat list: opens a menu
/// to switch their presence or open their profile (where the ZenTao picture
/// is changed).
class ChatSelfAvatarButton extends ConsumerWidget {
  const ChatSelfAvatarButton({
    super.key,
    required this.accountId,
    this.onViewProfile,
  });

  final String accountId;
  final OpenAccountProfile? onViewProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
    if (self == null) return const SizedBox.shrink();
    final users = ref.watch(chatUsersProvider(accountId)).value ?? {};
    final size = context.spacing.xl6 * 0.8;
    final presence = chatPresenceOf(users, self);
    return Tooltip(
      message: AppL10n.of(context).chatMyProfile,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        customBorder: const CircleBorder(),
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          showChatSelfMenu(
            context,
            ref,
            accountId: accountId,
            current: presence,
            at:
                box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ??
                Offset.zero,
            onOpenProfile: () => ChatUserProfileDialog.show(
              context,
              accountId: accountId,
              userId: self,
              onViewProfile: onViewProfile,
            ),
          );
        },
        child: ChatAvatar(
          name: chatUserName(context, users, self),
          imageUrl: users[self]?.avatarUrl,
          presence: presence,
          diameter: size,
        ),
      ),
    );
  }
}
