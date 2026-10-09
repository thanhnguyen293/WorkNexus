import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../features/connections/presentation/providers/zentao_profile_providers.dart';
import '../../features/connections/presentation/widgets/zentao_profile_dialog.dart';
import '../../l10n/app_localizations.dart';

class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId = ref.watch(selectedChatAccountIdProvider);
    if (accountId == null) return const SizedBox.shrink();
    final accounts = ref.watch(chatAccountsProvider);
    final account = accounts.firstWhere((a) => a.id == accountId);
    final profile = ref.watch(zenTaoProfileProvider(accountId)).asData?.value;
    final name = profile?.realname.isNotEmpty == true
        ? profile!.realname
        : account.handle;
    final s = context.spacing;
    final c = context.colors;
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: s.lg),
      child: PopupMenuButton<int>(
        tooltip: l.chatMyProfile,
        position: PopupMenuPosition.under,
        offset: Offset(s.xl3, -s.xl3),
        color: c.surface,
        surfaceTintColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.lg),
          side: BorderSide(color: c.border),
        ),
        constraints: const BoxConstraints(minWidth: 250),
        onSelected: (_) => ZenTaoProfileDialog.show(context, account),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            enabled: false,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodyStrong.copyWith(
                color: c.textPrimary,
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: 0,
            child: Text(
              l.chatMyProfile,
              style: context.typography.body.copyWith(color: c.textPrimary),
            ),
          ),
        ],
        child: UserAvatar(
          name: name,
          imageUrl: profile?.avatarUrl,
          diameter: s.xl6 * 0.9,
        ),
      ),
    );
  }
}
