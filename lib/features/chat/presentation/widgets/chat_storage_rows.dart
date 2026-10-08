import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';

/// "Used X of Y" with a bar that turns to the warning colour near the
/// limit.
class ChatStorageMeter extends StatelessWidget {
  const ChatStorageMeter({
    super.key,
    required this.usedBytes,
    required this.limitBytes,
  });

  final int usedBytes;
  final int limitBytes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = limitBytes <= 0
        ? 0.0
        : (usedBytes / limitBytes).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppL10n.of(context).chatStorageUsed(
            formatFileSize(usedBytes),
            formatFileSize(limitBytes),
          ),
          style: context.typography.body.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: context.spacing.md),
        LinearProgressIndicator(
          value: ratio,
          minHeight: context.spacing.md,
          borderRadius: BorderRadius.circular(context.radii.pill),
          color: ratio > 0.9 ? c.warning : c.accent,
          backgroundColor: c.surfaceSubtle,
        ),
      ],
    );
  }
}

/// Per-chat usage, largest first, each with a delete button; files no
/// stored message points to are summed as "Other files".
class ChatStorageChatList extends ConsumerWidget {
  const ChatStorageChatList({
    super.key,
    required this.usage,
    required this.onClear,
  });

  final ChatCacheUsage usage;
  final void Function(String accountId, String chatGid, String title) onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    if (usage.chats.isEmpty && usage.otherBytes <= 0) {
      return AppInlineNote(text: l.chatStorageEmpty);
    }
    final label = context.typography.captionStrong.copyWith(
      color: c.textSecondary,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.chatStorageByChat, style: label),
        SizedBox(height: s.sm),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final chat in usage.chats)
                _ChatRow(usage: chat, onClear: onClear),
              if (usage.otherBytes > 0)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.folder_outlined, color: c.textSecondary),
                  title: Text(
                    l.chatStorageOther,
                    style: context.typography.body.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  trailing: Text(
                    formatFileSize(usage.otherBytes),
                    style: context.typography.secondary.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.usage, required this.onClear});

  final ChatCacheChatUsage usage;
  final void Function(String accountId, String chatGid, String title) onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final users = ref.watch(chatUsersProvider(usage.accountId)).value ?? {};
    final chat = ref
        .watch(chatConversationsProvider(usage.accountId))
        .value
        ?.where((x) => x.gid == usage.chatGid)
        .firstOrNull;
    final title = chat == null
        ? usage.chatGid
        : chatTitle(context, chat, users);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: ChatAvatar(
        name: title,
        imageUrl: chatAvatarUrl(users, chat?.peerUserId),
        size: ChatAvatarSize.small,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.body.copyWith(color: c.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatFileSize(usage.bytes),
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
          IconButton(
            tooltip: AppL10n.of(context).chatDelete,
            onPressed: () => onClear(usage.accountId, usage.chatGid, title),
            icon: Icon(Icons.delete_outline, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Asks before deleting downloaded files; true when confirmed.
Future<bool> confirmChatStorageClear(
  BuildContext context,
  String question,
) async {
  final l = AppL10n.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.chatCancel),
        ),
        AppButton.error(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.chatDelete),
        ),
      ],
    ),
  );
  return ok ?? false;
}
