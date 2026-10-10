import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
import 'chat_storage_bar.dart';

/// Diameter of a row's avatar.
const double _kAvatar = 36;

/// Per-chat usage, largest first: each row's bar is scaled to the largest
/// chat so they compare at a glance, with its split by kind and a delete
/// button. Files no stored message points to are summed as "Other files".
class ChatStorageChatList extends StatelessWidget {
  const ChatStorageChatList({
    super.key,
    required this.usage,
    required this.onClear,
  });

  final ChatCacheUsage usage;
  final void Function(String accountId, String chatGid, String title) onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    if (usage.chats.isEmpty && usage.otherBytes <= 0) {
      return AppInlineNote(text: l.chatStorageEmpty);
    }
    final largest = [
      usage.otherBytes,
      for (final chat in usage.chats) chat.bytes,
    ].fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.chatStorageByChat,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: s.md),
        // A bordered card the rows scroll inside, so they never run under
        // the label above.
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radii.lg),
              border: Border.all(color: c.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.lg),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: s.lg),
                children: [
                  for (final (i, chat) in usage.chats.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.border),
                    _ChatRow(usage: chat, largest: largest, onClear: onClear),
                  ],
                  if (usage.otherBytes > 0) ...[
                    if (usage.chats.isNotEmpty)
                      Divider(height: 1, color: c.border),
                    _UsageRow(
                      leading: Container(
                        width: _kAvatar,
                        height: _kAvatar,
                        decoration: BoxDecoration(
                          color: c.surfaceSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIconsLight.folder,
                          size: s.xl4,
                          color: c.textSecondary,
                        ),
                      ),
                      title: l.chatStorageOther,
                      bytes: usage.otherBytes,
                      largest: largest,
                      kinds: [
                        (
                          label: l.chatStorageOther,
                          bytes: usage.otherBytes,
                          color: c.textTertiary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({
    required this.usage,
    required this.largest,
    required this.onClear,
  });

  final ChatCacheChatUsage usage;
  final int largest;
  final void Function(String accountId, String chatGid, String title) onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(chatUsersProvider(usage.accountId)).value ?? {};
    final chat = ref
        .watch(chatConversationsProvider(usage.accountId))
        .value
        ?.where((x) => x.gid == usage.chatGid)
        .firstOrNull;
    final title = chat == null
        ? usage.chatGid
        : chatTitle(context, chat, users);
    return _UsageRow(
      leading: ChatAvatar(
        name: title,
        imageUrl: chatAvatarUrl(users, chat?.peerUserId),
        diameter: _kAvatar,
      ),
      title: title,
      bytes: usage.bytes,
      largest: largest,
      kinds: chatStorageKinds(
        context,
        imageBytes: usage.imageBytes,
        videoBytes: usage.videoBytes,
        fileBytes: usage.fileBytes,
      ),
      onClear: () => onClear(usage.accountId, usage.chatGid, title),
    );
  }
}

/// One storage row: who, how much, a bar scaled to the [largest] row split
/// by [kinds], the kinds in words under it, and delete ([onClear]).
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.leading,
    required this.title,
    required this.bytes,
    required this.largest,
    required this.kinds,
    this.onClear,
  });

  final Widget leading;
  final String title;
  final int bytes;
  final int largest;
  final List<ChatStorageKind> kinds;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    // Largest first, empty kinds left out: "Videos 80 MB · Photos 19 MB".
    final split = [...kinds.where((k) => k.bytes > 0)]
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.lg),
      child: Row(
        children: [
          leading,
          SizedBox(width: s.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.body.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: s.md),
                    Text(
                      formatFileSize(bytes),
                      style: context.typography.secondaryStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: s.xs),
                ChatStorageBar(
                  total: largest,
                  parts: [
                    for (final k in kinds) (bytes: k.bytes, color: k.color),
                  ],
                  height: s.xs,
                ),
                if (split.length > 1 || onClear != null) ...[
                  SizedBox(height: s.xxs),
                  Text(
                    [
                      for (final k in split)
                        '${k.label} ${formatFileSize(k.bytes)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: s.sm),
          if (onClear case final clear?)
            IconButton(
              tooltip: AppL10n.of(context).chatDelete,
              onPressed: clear,
              visualDensity: VisualDensity.compact,
              mouseCursor: SystemMouseCursors.click,
              hoverColor: c.mixT(c.error, 0.12),
              icon: Icon(
                PhosphorIconsLight.trash,
                size: s.xl3,
                color: c.textSecondary,
              ),
            )
          else
            // Lines the sizes up with the deletable rows'.
            SizedBox(width: s.xl6),
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
