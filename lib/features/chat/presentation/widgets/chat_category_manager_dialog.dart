import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_category_providers.dart';
import 'chat_avatar.dart';
import 'chat_category_actions.dart';

/// The user's category tags, each to rename or delete. New tags come from
/// filing a chat (its right-click menu), as a tag is only a name on chats.
class ChatCategoryManagerDialog extends ConsumerWidget {
  const ChatCategoryManagerDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ChatCategoryManagerDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final categories = ref.watch(chatCategoriesProvider).keys.toList();
    return AppDialogFrame(
      title: l.chatManageCategories,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              categories.isEmpty
                  ? l.chatNoCategories
                  : l.chatManageCategoriesHint,
              style: context.typography.bodySm.copyWith(color: c.textSecondary),
            ),
            SizedBox(height: s.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final name in categories)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: s.xs),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.tag500,
                            size: context.sizes.iconLg,
                            color: chatNameHue(c, name),
                          ),
                          SizedBox(width: s.md),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.body.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          AppIconButton(
                            icon: LucideIcons.pencil300,
                            tooltip: l.chatRenameCategory,
                            onPressed: () => renameChatCategory(
                              context,
                              ref,
                              category: name,
                            ),
                          ),
                          AppIconButton(
                            icon: LucideIcons.trash2300,
                            tooltip: l.chatDeleteCategory,
                            color: c.error,
                            onPressed: () => deleteChatCategory(
                              context,
                              ref,
                              category: name,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
