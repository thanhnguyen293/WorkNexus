import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';

/// The chat list's input look (filled, hairline border), for the new-chat
/// dialog's search and group-name fields.
InputDecoration chatFieldDecoration(
  BuildContext context, {
  required String hint,
  IconData? icon,
}) {
  final c = context.colors;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(context.radii.md),
    borderSide: BorderSide(color: c.border),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: c.background,
    hintText: hint,
    hintStyle: context.typography.body.copyWith(color: c.textTertiary),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: context.spacing.xl3, color: c.textTertiary),
    contentPadding: EdgeInsets.symmetric(
      vertical: context.spacing.lg,
      horizontal: context.spacing.lg,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: c.accent)),
  );
}

/// The people picker of the new-chat dialog: picked people as pills, a
/// search box, and the users as chat-list-like rows with a round tick.
class NewChatPeople extends ConsumerWidget {
  const NewChatPeople({
    super.key,
    required this.accountId,
    required this.search,
    required this.selected,
    required this.onToggle,
  });

  final String accountId;
  final TextEditingController search;
  final List<int> selected;
  final void Function(int userId) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final users = ref.watch(chatUsersProvider(accountId)).value ?? {};
    final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
    return ValueListenableBuilder(
      valueListenable: search,
      builder: (context, value, _) {
        final q = value.text.trim().toLowerCase();
        final people =
            [
              for (final u in users.values)
                if (u.userId != self &&
                    !u.deleted &&
                    (q.isEmpty ||
                        u.realname.toLowerCase().contains(q) ||
                        u.account.toLowerCase().contains(q)))
                  u,
            ]..sort(
              (a, b) =>
                  _name(a).toLowerCase().compareTo(_name(b).toLowerCase()),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: search,
              autofocus: true,
              style: context.typography.body.copyWith(
                color: context.colors.textPrimary,
              ),
              decoration: chatFieldDecoration(
                context,
                hint: l.chatSearchPeople,
                icon: Icons.search,
              ),
            ),
            if (selected.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: s.lg),
                child: Wrap(
                  spacing: s.sm,
                  runSpacing: s.sm,
                  children: [
                    for (final id in selected)
                      _PickedPill(
                        name: chatUserName(context, users, id),
                        avatarUrl: chatAvatarUrl(users, id),
                        onRemove: () => onToggle(id),
                      ),
                  ],
                ),
              ),
            SizedBox(height: s.md),
            Flexible(
              child: people.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(s.xl),
                      child: users.isEmpty
                          ? const AppInlineSpinner()
                          : AppInlineNote(text: l.chatNoPeople),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final u = people[i];
                        return _PersonRow(
                          user: u,
                          name: _name(u),
                          picked: selected.contains(u.userId),
                          onTap: () => onToggle(u.userId),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  static String _name(ChatUser u) =>
      u.realname.isNotEmpty ? u.realname : u.account;
}

/// A user like a chat-list row: avatar (with presence), name, account and
/// role, and a round tick; picked rows are tinted.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.user,
    required this.name,
    required this.picked,
    required this.onTap,
  });

  final ChatUser user;
  final String name;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final tick = s.xl4;
    return Material(
      color: picked ? c.selectionFill : Colors.transparent,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.radii.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
          child: Row(
            children: [
              ChatAvatar(
                name: name,
                imageUrl: user.avatarUrl,
                presence: chatPresenceOf({user.userId: user}, user.userId),
              ),
              SizedBox(width: s.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      ['@${user.account}', ?user.role].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: tick,
                height: tick,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: picked ? c.accent : Colors.transparent,
                  border: Border.all(
                    color: picked ? c.accent : c.borderStrong,
                    width: 1.5,
                  ),
                ),
                child: picked
                    ? Icon(Icons.check_rounded, size: s.xl2, color: c.onAccent)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picked person: small avatar, name and ×.
class _PickedPill extends StatelessWidget {
  const _PickedPill({
    required this.name,
    required this.avatarUrl,
    required this.onRemove,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.fromLTRB(s.xxs, s.xxs, s.xs, s.xxs),
      decoration: BoxDecoration(
        color: c.selectionFill,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar(
            name: name,
            imageUrl: avatarUrl,
            size: ChatAvatarSize.small,
          ),
          SizedBox(width: s.sm),
          Text(
            name,
            style: context.typography.secondary.copyWith(color: c.textPrimary),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onRemove,
            child: Padding(
              padding: EdgeInsets.all(s.xs),
              child: Icon(
                Icons.close_rounded,
                size: s.xl2,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
