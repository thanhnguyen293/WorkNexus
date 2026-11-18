import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_category_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_name_dialog.dart';
import 'chat_snack.dart';
import 'chat_tab_chip.dart';

/// Files [chat] under a category: an existing one picked from chips, or a
/// new one typed; one already filed can also be taken out.
Future<void> showChatCategoryPicker(
  BuildContext context,
  WidgetRef ref, {
  required ChatConversation chat,
}) {
  final l = AppL10n.of(context);
  final controller = ref.read(chatCategoryControllerProvider);
  final existing = ref.read(chatCategoriesProvider).keys.toList();
  return ChatNameDialog.show(
    context,
    title: l.chatCategorizeTitle,
    initial: chat.category,
    hint: l.chatCategoryName,
    onSave: (name) => controller.setCategory(chat, name),
    extra: [
      if (existing.isNotEmpty)
        (name) => Padding(
          padding: EdgeInsets.only(top: context.spacing.lg),
          child: ValueListenableBuilder(
            valueListenable: name,
            builder: (context, value, _) => Wrap(
              spacing: context.spacing.sm,
              runSpacing: context.spacing.sm,
              children: [
                for (final c in existing)
                  ChatTabChip(
                    label: c,
                    icon: LucideIcons.folder400,
                    selected: value.text.trim() == c,
                    onTap: () => name.text = c,
                  ),
              ],
            ),
          ),
        ),
      if (chat.category.isNotEmpty)
        (_) => Padding(
          padding: EdgeInsets.only(top: context.spacing.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (dialog) => AppButton.textNeutral(
                size: AppButtonSize.small,
                icon: LucideIcons.folderMinus300,
                onPressed: () async {
                  final result = await controller.setCategory(chat, '');
                  if (!dialog.mounted) return;
                  switch (result) {
                    case Ok():
                      Navigator.of(dialog).pop();
                    case Err(:final failure):
                      showChatFailure(dialog, failure);
                  }
                },
                child: Text(l.chatRemoveCategory),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Renames [category] (every chat in it is refiled); the list's filter
/// follows it to the new name.
Future<void> renameChatCategory(
  BuildContext context,
  WidgetRef ref, {
  required String category,
}) async {
  final l = AppL10n.of(context);
  final accountId = ref.read(selectedChatAccountIdProvider);
  if (accountId == null) return;
  final chats = ref.read(chatConversationsProvider(accountId)).value ?? [];
  await ChatNameDialog.show(
    context,
    title: l.chatRenameCategory,
    initial: category,
    hint: l.chatCategoryName,
    onSave: (name) async {
      final result = await ref
          .read(chatCategoryControllerProvider)
          .rename(accountId, chats, from: category, to: name);
      final picked = ref.read(chatListCategoriesProvider);
      if (result is Ok && picked.contains(category)) {
        ref.read(chatListCategoriesProvider.notifier).state = {
          ...picked.where((c) => c != category),
          name.trim(),
        };
      }
      return result;
    },
  );
}

/// Deletes [category] after asking: its chats stay, uncategorised.
Future<void> deleteChatCategory(
  BuildContext context,
  WidgetRef ref, {
  required String category,
}) async {
  final l = AppL10n.of(context);
  final accountId = ref.read(selectedChatAccountIdProvider);
  if (accountId == null) return;
  final confirmed = await AppConfirmDialog.show(
    context,
    title: l.chatDeleteCategory,
    message: l.chatDeleteCategoryConfirm(category),
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  final chats = ref.read(chatConversationsProvider(accountId)).value ?? [];
  final result = await ref
      .read(chatCategoryControllerProvider)
      .delete(accountId, chats, category);
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}
