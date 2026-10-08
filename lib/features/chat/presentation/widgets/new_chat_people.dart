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

/// The people picker of the new-chat dialog: the picked people as chips,
/// a search box and the matching users with checkboxes.
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
    final c = context.colors;
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
            if (selected.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: s.md),
                child: Wrap(
                  spacing: s.sm,
                  runSpacing: s.sm,
                  children: [
                    for (final id in selected)
                      InputChip(
                        avatar: ChatAvatar(
                          name: chatUserName(context, users, id),
                          imageUrl: chatAvatarUrl(users, id),
                          size: ChatAvatarSize.small,
                        ),
                        label: Text(chatUserName(context, users, id)),
                        onDeleted: () => onToggle(id),
                      ),
                  ],
                ),
              ),
            TextField(
              controller: search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.chatSearchPeople,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radii.md),
                ),
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
                        return CheckboxListTile(
                          dense: true,
                          value: selected.contains(u.userId),
                          onChanged: (_) => onToggle(u.userId),
                          secondary: ChatAvatar(
                            name: _name(u),
                            imageUrl: u.avatarUrl,
                          ),
                          title: Text(
                            _name(u),
                            style: context.typography.bodyStrong.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '@${u.account}${u.role == null ? '' : ' · ${u.role}'}',
                            style: context.typography.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
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
