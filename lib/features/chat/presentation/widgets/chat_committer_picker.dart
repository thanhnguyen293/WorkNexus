import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_pick_tick.dart';

/// The group settings' list of members to tick: who may post when only
/// chosen members may. The owner always may, so is not listed.
class ChatCommitterPicker extends ConsumerWidget {
  const ChatCommitterPicker({
    super.key,
    required this.thread,
    required this.chat,
    required this.picked,
    required this.onToggle,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Set<int> picked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(chatUsersProvider(thread.accountId)).value ?? {};
    return switch (ref.watch(chatMembersProvider(thread))) {
      AsyncData(value: Ok(:final value)) => ListView(
        shrinkWrap: true,
        children: [
          for (final id in value)
            if (users[id]?.account != chat.ownerAccount)
              _MemberTick(
                name: chatUserName(context, users, id),
                imageUrl: chatAvatarUrl(users, id),
                picked: picked.contains(id),
                onTap: () => onToggle(id),
              ),
        ],
      ),
      AsyncData(value: Err()) || AsyncError() => AppInlineNote(
        text: AppL10n.of(context).chatMembersFailed,
        isError: true,
      ),
      _ => const AppInlineSpinner(),
    };
  }
}

class _MemberTick extends StatelessWidget {
  const _MemberTick({
    required this.name,
    required this.imageUrl,
    required this.picked,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return Material(
      color: picked ? c.selectionFill : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
          child: Row(
            children: [
              ChatAvatar(name: name, imageUrl: imageUrl),
              SizedBox(width: s.lg),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              ChatPickTick(picked: picked),
            ],
          ),
        ),
      ),
    );
  }
}
