import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';
import 'chat_storage_meter.dart';
import 'chat_storage_rows.dart';

/// Limits users can pick for the attachment cache, in MB.
const _kLimitsMb = [512, 1024, 2048, 5120, 10240];

/// A limit as a round figure: "512 MB", "2 GB" — never "512.0 MB".
String _limitLabel(int mb) => mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB';

/// Disk space of downloaded chat files: how much is used against the
/// limit, the limit itself, per-chat usage with delete, and "clear all".
/// The chat part of the app's storage dialog.
class ChatStoragePanel extends ConsumerWidget {
  const ChatStoragePanel({super.key});

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (usage) {
          AsyncData(value: Ok(:final value)) => ChatStorageMeter(
            usage: value,
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
            SizedBox(
              width: s.xl6 * 3,
              child: AppDropdown<int>(
                value: _kLimitsMb.contains(limitMb)
                    ? limitMb
                    : _kLimitsMb.first,
                values: _kLimitsMb,
                labelOf: _limitLabel,
                onChanged: (mb) {
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
            ),
          ],
        ),
        Text(
          l.chatStorageLimitHint,
          style: context.typography.caption.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: s.xl3),
        if (usage case AsyncData(value: Ok(:final value)))
          // Its rows scroll inside; the dialog around it scrolls too.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: s.xl6 * 7),
            child: ChatStorageChatList(
              usage: value,
              onClear: (accountId, chatGid, title) => clear(
                accountId: accountId,
                chatGid: chatGid,
                question: l.chatStorageClearChatConfirm(title),
              ),
            ),
          ),
        SizedBox(height: s.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.error(
            onPressed: () => clear(question: l.chatStorageClearAllConfirm),
            child: Text(l.chatStorageClearAll),
          ),
        ),
      ],
    );
  }
}
