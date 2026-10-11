import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/open_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_side_panel_frame.dart';
import 'chat_storage_bar.dart';

/// The info panel's storage card: how much of the chat cache limit this
/// chat's downloads take, split into photos, videos and files.
class ChatInfoStorageCard extends ConsumerWidget {
  const ChatInfoStorageCard({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = switch (ref.watch(chatCacheUsageProvider).value) {
      Ok(:final value) => value,
      _ => null,
    };
    // Nothing to measure yet (or it failed): no card rather than zeros.
    if (usage == null) return const SizedBox.shrink();
    final chat =
        usage.chats
            .where(
              (u) =>
                  u.accountId == thread.accountId &&
                  u.chatGid == thread.chatGid,
            )
            .firstOrNull ??
        ChatCacheChatUsage(
          accountId: thread.accountId,
          chatGid: thread.chatGid,
          bytes: 0,
        );
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final kinds = chatStorageKinds(
      context,
      imageBytes: chat.imageBytes,
      videoBytes: chat.videoBytes,
      fileBytes: chat.fileBytes,
    );
    return ChatPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.chatStorageThisChat,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              // Compact like the other cards' "See all": no taller than the
              // title.
              TextButton(
                onPressed: () => ref.read(openStorageProvider)?.call(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: s.md),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l.chatStorageManage),
              ),
            ],
          ),
          SizedBox(height: s.md),
          Text(
            l.chatStorageUsed(
              formatFileSize(chat.bytes),
              formatFileSize(usage.limitBytes),
            ),
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
          SizedBox(height: s.sm),
          ChatStorageBar(
            total: usage.limitBytes,
            parts: [for (final k in kinds) (bytes: k.bytes, color: k.color)],
          ),
          SizedBox(height: s.lg),
          for (final k in kinds)
            Padding(
              padding: EdgeInsets.only(top: s.xs),
              child: Row(
                children: [
                  Container(
                    width: s.md,
                    height: s.md,
                    decoration: BoxDecoration(
                      color: k.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: s.md),
                  Expanded(
                    child: Text(
                      k.label,
                      style: context.typography.secondary.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    formatFileSize(k.bytes),
                    style: context.typography.secondary.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
