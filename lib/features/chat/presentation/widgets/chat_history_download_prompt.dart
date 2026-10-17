import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_history_progress.dart';
import '../providers/chat_history_download.dart';
import '../providers/chat_providers.dart';

/// Below the search results: search only sees messages stored on this
/// device, so when every stored match is listed ([offer]) and older history
/// is not stored yet, this offers to download it — then shows its progress
/// until it is done, cancelled or failed.
class ChatHistoryDownloadPrompt extends ConsumerWidget {
  const ChatHistoryDownloadPrompt({
    super.key,
    required this.thread,
    required this.offer,
  });

  final ChatThreadKey thread;
  final bool offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(chatHistoryDownloadProvider(thread));
    ChatHistoryDownloadController controller() =>
        ref.read(chatHistoryDownloadProvider(thread).notifier);
    // Hidden until known: offering a download there is nothing to get for
    // would only mislead.
    final complete =
        ref.watch(chatHistoryCompleteProvider(thread)).value ?? true;
    final Widget content;
    switch (download) {
      case ChatHistoryIdle() when offer && !complete:
        content = _Offer(onDownload: () => controller().start());
      case ChatHistoryRunning(:final progress):
        content = _Progress(
          progress: progress,
          onCancel: () => controller().cancel(),
        );
      case ChatHistoryFailed():
        content = _Failed(onRetry: () => controller().start());
      case ChatHistoryIdle() || ChatHistoryDone():
        return const SizedBox.shrink();
    }
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(
          top: BorderSide(color: c.border, width: context.borders.hairline),
        ),
      ),
      child: content,
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.chatHistoryOnlyStored,
          style: context.typography.secondary.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        AppButton.text(
          size: AppButtonSize.small,
          icon: LucideIcons.history300,
          onPressed: onDownload,
          child: Text(l.chatHistoryDownload),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress, required this.onCancel});

  final ChatHistoryProgress? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final p = progress;
    final style = context.typography.secondary.copyWith(color: c.textSecondary);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l.chatHistoryDownloading, style: style)),
                  if (p != null && p.total > 0)
                    Text(
                      l.chatHistoryDownloadProgress(p.stored, p.total),
                      style: style,
                    ),
                ],
              ),
              SizedBox(height: context.spacing.xs),
              LinearProgressIndicator(
                value: p?.fraction,
                color: c.accent,
                backgroundColor: c.border,
              ),
            ],
          ),
        ),
        SizedBox(width: context.spacing.xs),
        AppIconButton(
          icon: LucideIcons.x300,
          size: AppIconButtonSize.small,
          tooltip: l.chatCancel,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l.chatHistoryDownloadFailed,
            style: context.typography.secondary.copyWith(
              color: context.colors.error,
            ),
          ),
        ),
        AppButton.text(
          size: AppButtonSize.small,
          onPressed: onRetry,
          child: Text(l.retry),
        ),
      ],
    );
  }
}
