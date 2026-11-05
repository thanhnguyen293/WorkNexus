import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../detail_providers.dart';

/// Disk taken by ticket attachments — videos kept by the stream cache and
/// files opened this session — with a button to clear it. The ticket part of
/// the app's storage dialog.
class AttachmentStoragePanel extends ConsumerStatefulWidget {
  const AttachmentStoragePanel({super.key});

  @override
  ConsumerState<AttachmentStoragePanel> createState() =>
      _AttachmentStoragePanelState();
}

class _AttachmentStoragePanelState
    extends ConsumerState<AttachmentStoragePanel> {
  var _clearing = false;

  Future<void> _clear() async {
    final l = AppL10n.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l.chatStorageClearTitle,
      message: l.attachmentStorageClearConfirm,
      confirmLabel: l.attachmentStorageClear,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _clearing = true);
    final result = await getIt<TicketDetailService>().clearAttachmentStorage();
    ref
      ..invalidate(attachmentStorageBytesProvider)
      ..invalidate(attachmentThumbnailProvider);
    if (!mounted) return;
    setState(() => _clearing = false);
    showAppSnack(
      context,
      result is Ok ? l.chatStorageCleared : l.attachmentStorageFailed,
      isError: result is Err,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final bytes = ref.watch(attachmentStorageBytesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.attachmentStorageHint,
          style: context.typography.caption.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: s.xl),
        switch (bytes) {
          AsyncData(value: Ok(:final value)) => Text(
            l.attachmentStorageUsed(formatFileSize(value) ?? ''),
            style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
          ),
          AsyncData(value: Err()) || AsyncError() => AppInlineNote(
            text: l.attachmentStorageFailed,
            isError: true,
          ),
          _ => const AppInlineSpinner(),
        },
        SizedBox(height: s.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.error(
            isDisabled: switch (bytes) {
              AsyncData(value: Ok(:final value)) => value == 0,
              _ => false,
            },
            isLoading: _clearing,
            onPressed: _clear,
            child: Text(l.attachmentStorageClear),
          ),
        ),
      ],
    );
  }
}
