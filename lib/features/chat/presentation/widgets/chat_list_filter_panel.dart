import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../../../core/widgets/unread_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_category_providers.dart';
import 'chat_avatar.dart';
import 'chat_category_manager_dialog.dart';

/// The chat list's "Categorize" menu: by status (all chats or only unread
/// ones, pick one) and by category tags (pick any; none means all), then a
/// way to manage the tags. Stays open while picking.
class ChatListFilterPanel extends ConsumerWidget {
  const ChatListFilterPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final unreadOnly = ref.watch(chatListUnreadOnlyProvider);
    final categories = ref.watch(chatCategoriesProvider);
    final picked = ref.watch(chatListFilterProvider).categories;
    void setUnread(bool v) =>
        ref.read(chatListUnreadOnlyProvider.notifier).state = v;
    void toggle(String name) {
      final next = {...picked};
      if (!next.remove(name)) next.add(name);
      ref.read(chatListCategoriesProvider.notifier).state = next;
    }

    return AppPopupCard(
      padding: EdgeInsets.all(s.sm),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(l.chatFilterByStatus),
            _Row(
              leading: _Radio(selected: !unreadOnly),
              label: l.chatFilterAll,
              onTap: () => setUnread(false),
            ),
            _Row(
              leading: _Radio(selected: unreadOnly),
              label: l.chatFilterUnread,
              onTap: () => setUnread(true),
            ),
            const _Divider(),
            _Heading(l.chatFilterByCategory),
            if (categories.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(s.lg, 0, s.lg, s.md),
                child: Text(
                  l.chatNoCategories,
                  style: context.typography.bodySm.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
            for (final MapEntry(key: name, value: unread) in categories.entries)
              _Row(
                leading: _Check(checked: picked.contains(name)),
                tag: chatNameHue(c, name),
                label: name,
                trailing: unread > 0 ? UnreadBadge(count: unread) : null,
                onTap: () => toggle(name),
              ),
            const _Divider(),
            _Row(
              leading: Icon(
                LucideIcons.settings2300,
                size: context.sizes.iconLg,
                color: c.textSecondary,
              ),
              label: l.chatManageCategories,
              onTap: () {
                onClose();
                ChatCategoryManagerDialog.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(s.lg, s.md, s.lg, s.sm),
      child: Text(
        text,
        style: context.typography.bodySm.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

/// One pickable line: [leading] control, an optional coloured [tag], the
/// label and an optional [trailing] count.
class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.label,
    required this.onTap,
    this.tag,
    this.trailing,
  });

  final Widget leading;
  final String label;
  final VoidCallback onTap;
  final Color? tag;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
        child: Row(
          children: [
            leading,
            SizedBox(width: s.lg),
            if (tag case final tag?) ...[
              Icon(LucideIcons.tag500, size: context.sizes.iconLg, color: tag),
              SizedBox(width: s.md),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.body.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            if (trailing case final trailing?) ...[
              SizedBox(width: s.md),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Icon(
    selected ? LucideIcons.circleDot500 : LucideIcons.circle300,
    size: context.sizes.iconLg,
    color: selected ? context.colors.accent : context.colors.textTertiary,
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => Icon(
    checked ? LucideIcons.squareCheck500 : LucideIcons.square300,
    size: context.sizes.iconLg,
    color: checked ? context.colors.accent : context.colors.textTertiary,
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
    child: Divider(height: 1, thickness: 1, color: context.colors.border),
  );
}
