import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'chat_storage_rows.dart';

/// Limits users can pick for the attachment cache, in MB.
const _kLimitsMb = [512, 1024, 2048, 5120, 10240];

/// Disk space of downloaded chat files: how much is used against the
/// limit, the limit itself, per-chat usage with delete, and "clear all".
class ChatStorageDialog extends ConsumerWidget {
  const ChatStorageDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ChatStorageDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final limitMb = ref.watch(
      appSettingsProvider.select((st) => st.chatCacheLimitMb),
    );
    final limitBytes = limitMb * 1024 * 1024;
    final usage = ref.watch(chatCacheUsageProvider);

    Future<void> clear({
      String? accountId,
      String? chatGid,
      required String question,
    }) async {
      if (!await confirmChatStorageClear(context, question)) return;
      final result = await ref
          .read(chatControllerProvider)
          .clearCache(accountId: accountId, chatGid: chatGid);
      ref
        ..invalidate(chatCacheUsageProvider)
        ..invalidate(chatAttachmentCachedProvider)
        ..invalidate(chatAttachmentProvider)
        ..invalidate(chatVideoThumbnailProvider);
      if (!context.mounted) return;
      switch (result) {
        case Ok():
          showChatSnack(context, l.chatStorageCleared);
        case Err(:final failure):
          showChatFailure(context, failure);
      }
    }

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.all(s.xl5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.chatStorage,
                style: context.typography.titleLg.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(height: s.xl3),
              switch (usage) {
                AsyncData(value: Ok(:final value)) => ChatStorageMeter(
                  usedBytes: value.totalBytes,
                  limitBytes: limitBytes,
                ),
                AsyncData(value: Err()) || AsyncError() => AppInlineNote(
                  text: l.chatAttachmentFailed,
                  isError: true,
                ),
                _ => const AppInlineSpinner(),
              },
              SizedBox(height: s.xl3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.chatStorageLimit,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _kLimitsMb.contains(limitMb) ? limitMb : null,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final mb in _kLimitsMb)
                        DropdownMenuItem(
                          value: mb,
                          child: Text(formatFileSize(mb * 1024 * 1024)),
                        ),
                    ],
                    onChanged: (mb) {
                      if (mb == null) return;
                      ref
                          .read(appSettingsProvider.notifier)
                          .setChatCacheLimitMb(mb);
                      // Lowering the limit trims; show the new usage after.
                      Future<void>.delayed(
                        const Duration(milliseconds: 500),
                        () => ref.invalidate(chatCacheUsageProvider),
                      );
                    },
                  ),
                ],
              ),
              Text(
                l.chatStorageLimitHint,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: s.xl3),
              if (usage case AsyncData(value: Ok(:final value)))
                Flexible(
                  child: ChatStorageChatList(
                    usage: value,
                    onClear: (accountId, chatGid, title) => clear(
                      accountId: accountId,
                      chatGid: chatGid,
                      question: l.chatStorageClearChatConfirm(title),
                    ),
                  ),
                ),
              SizedBox(height: s.xl3),
              Row(
                children: [
                  AppButton.error(
                    onPressed: () =>
                        clear(question: l.chatStorageClearAllConfirm),
                    child: Text(l.chatStorageClearAll),
                  ),
                  const Spacer(),
                  AppButton.textNeutral(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.chatClosePanel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
