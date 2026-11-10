import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/section_label.dart';
import '../providers/zentao_doc_providers.dart';
import '../util/zentao_file_preview.dart';
import 'zentao_doc_file_preview.dart';

/// A document's attached files. A file the app can show (Markdown, text,
/// an image) opens in place under its row with the eye — a tap on the row
/// does the same; any file saves to Downloads with the download button.
class ZenTaoDocFiles extends StatelessWidget {
  const ZenTaoDocFiles({
    super.key,
    required this.account,
    required this.files,
    this.openFirst = false,
  });

  final Account account;
  final List<TicketAttachment> files;

  /// Shows the first file in place from the start: a document that is only
  /// an attachment then reads like any other.
  final bool openFirst;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('${l.attachments} · ${files.length}'),
        SizedBox(height: context.spacing.md),
        for (var i = 0; i < files.length; i++) ...[
          if (i > 0) SizedBox(height: context.spacing.sm),
          _FileRow(
            account: account,
            file: files[i],
            initiallyOpen: openFirst && i == 0,
          ),
        ],
      ],
    );
  }
}

class _FileRow extends ConsumerStatefulWidget {
  const _FileRow({
    required this.account,
    required this.file,
    required this.initiallyOpen,
  });

  final Account account;
  final TicketAttachment file;
  final bool initiallyOpen;

  @override
  ConsumerState<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends ConsumerState<_FileRow> {
  bool _saving = false;
  late final _kind = zenTaoFilePreviewOf(widget.file);
  late bool _open = widget.initiallyOpen && _kind != ZenTaoFilePreview.none;

  bool get _previewable => _kind != ZenTaoFilePreview.none;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final res = await ref
        .read(zenTaoDocRepositoryProvider)
        .saveFile(widget.account, widget.file);
    if (!mounted) return;
    setState(() => _saving = false);
    final l = AppL10n.of(context);
    switch (res) {
      case Ok(:final value):
        showAppSnack(context, l.savedToDownloads);
        await revealInFileManager(value);
      case Err():
        showAppSnack(context, l.saveFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final file = widget.file;
    final subtitle = [
      ?formatFileSize(file.size),
      if ((file.addedBy ?? '').isNotEmpty) file.addedBy!,
    ].join(' · ');

    final l = AppL10n.of(context);
    final row = HoverSurface(
      onTap: _previewable ? () => setState(() => _open = !_open) : _save,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.sm,
      ),
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(color: c.border),
      child: Row(
        children: [
          Icon(
            LucideIcons.paperclip300,
            size: context.sizes.iconMd,
            color: c.info,
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.secondary.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    subtitle,
                    style: context.typography.caption.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: context.spacing.md),
          if (_previewable)
            AppIconButton(
              icon: _open ? LucideIcons.eyeOff300 : LucideIcons.eye300,
              tooltip: _open ? l.docsHidePreview : l.docsPreviewFile,
              size: AppIconButtonSize.small,
              selected: _open,
              onPressed: () => setState(() => _open = !_open),
            ),
          AppIconButton(
            icon: LucideIcons.download300,
            tooltip: l.docsDownloadFile,
            size: AppIconButtonSize.small,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
    if (!_open) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        SizedBox(height: context.spacing.md),
        ZenTaoDocFilePreview(
          account: widget.account,
          file: widget.file,
          kind: _kind,
        ),
      ],
    );
  }
}
