import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_user_profile_dialog.dart';

/// The signed-in user's own avatar at the top of the chat list: opens their
/// profile, where the ZenTao picture is changed.
class ChatSelfAvatarButton extends ConsumerWidget {
  const ChatSelfAvatarButton({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
    if (self == null) return const SizedBox.shrink();
    final users = ref.watch(chatUsersProvider(accountId)).value ?? {};
    final size = context.spacing.xl6 * 0.8;
    return Tooltip(
      message: AppL10n.of(context).chatMyProfile,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ChatUserProfileDialog.show(
          context,
          accountId: accountId,
          userId: self,
        ),
        child: ChatAvatar(
          name: chatUserName(context, users, self),
          imageUrl: users[self]?.avatarUrl,
          presence: chatPresenceOf(users, self),
          diameter: size,
        ),
      ),
    );
  }
}
