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

/// Below the search: search only sees messages stored on this device, so
/// while a chat is [searching] and its stored history does not yet go back
/// as far as the search period, this downloads the rest — at once, without
/// asking — and shows its progress until it is done, stopped or failed.
class ChatHistoryDownloadPrompt extends ConsumerWidget {
  const ChatHistoryDownloadPrompt({
    super.key,
    required this.thread,
    required this.searching,
  });

  final ChatThreadKey thread;
  final bool searching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(chatHistoryDownloadProvider(thread));
    ChatHistoryDownloadController controller() =>
        ref.read(chatHistoryDownloadProvider(thread).notifier);
    // Only once known — and not the previous answer while another period
    // is checked: unknown is not a reason to ask the server.
    final completeAsync = ref.watch(chatHistoryCompleteProvider(thread));
    final complete = completeAsync.isLoading ? null : completeAsync.value;
    if (download is ChatHistoryIdle && searching && complete == false) {
      // Not during build: starting changes provider state.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) controller().start();
      });
    }
    final Widget content;
    switch (download) {
      case ChatHistoryRunning(:final progress):
        content = _Progress(
          progress: progress,
          onCancel: () => controller().cancel(),
        );
      case ChatHistoryCancelled() when searching:
        content = _Stopped(
          message: AppL10n.of(context).chatHistoryDownloadStopped,
          action: AppL10n.of(context).chatHistoryDownloadResume,
          onAction: () => controller().start(),
        );
      case ChatHistoryFailed():
        content = _Stopped(
          message: AppL10n.of(context).chatHistoryDownloadFailed,
          action: AppL10n.of(context).retry,
          onAction: () => controller().start(),
          isError: true,
        );
      case ChatHistoryIdle() || ChatHistoryDone() || ChatHistoryCancelled():
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
                  if (p != null)
                    Text(
                      p.total > 0
                          ? l.chatHistoryDownloadProgress(p.stored, p.total)
                          : l.chatHistoryDownloadedCount(p.stored),
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
          // Not "Cancel": beside the search bar's own close button.
          tooltip: l.chatHistoryDownloadStop,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

/// Why the download is not running, and how to start it again.
class _Stopped extends StatelessWidget {
  const _Stopped({
    required this.message,
    required this.action,
    required this.onAction,
    this.isError = false,
  });

  final String message;
  final String action;
  final VoidCallback onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: context.typography.secondary.copyWith(
              color: isError ? c.error : c.textSecondary,
            ),
          ),
        ),
        AppButton.text(
          size: AppButtonSize.small,
          onPressed: onAction,
          child: Text(action),
        ),
      ],
    );
  }
}
