import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_doc.dart';
import '../../domain/entities/zentao_doc_export_format.dart';
import '../providers/zentao_doc_providers.dart';

/// The reader's Export button: a menu of ZenTao's export choices — Markdown,
/// HTML, a JSON backup — each saving the document to Downloads and showing
/// the file there.
class ZenTaoDocExportButton extends ConsumerStatefulWidget {
  const ZenTaoDocExportButton({
    super.key,
    required this.account,
    required this.doc,
  });

  final Account account;
  final ZenTaoDoc doc;

  @override
  ConsumerState<ZenTaoDocExportButton> createState() =>
      _ZenTaoDocExportButtonState();
}

class _ZenTaoDocExportButtonState extends ConsumerState<ZenTaoDocExportButton> {
  bool _saving = false;

  static const _formats = ZenTaoDocExportFormat.values;

  Future<void> _pick() async {
    final l = AppL10n.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final at =
        box?.localToGlobal(Offset(0, box.size.height + context.spacing.xs)) ??
        Offset.zero;
    final picked = await showAppContextMenu(
      context,
      at: at,
      entries: [
        for (final f in _formats)
          AppMenuEntry(
            icon: switch (f) {
              ZenTaoDocExportFormat.markdown => LucideIcons.fileText300,
              ZenTaoDocExportFormat.html => LucideIcons.fileCode300,
              ZenTaoDocExportFormat.backup => LucideIcons.fileJson300,
            },
            label: switch (f) {
              ZenTaoDocExportFormat.markdown => l.docsExportMarkdown,
              ZenTaoDocExportFormat.html => l.docsExportHtml,
              ZenTaoDocExportFormat.backup => l.docsExportBackup,
            },
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _saving = true);
    final res = await ref.read(exportZenTaoDocProvider)(
      widget.account,
      widget.doc,
      _formats[picked],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (res) {
      case Ok(:final value):
        showAppSnack(context, l.savedToDownloads);
        await revealInFileManager(value);
      case Err():
        showAppSnack(context, l.saveFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: LucideIcons.share300,
    tooltip: AppL10n.of(context).docsExport,
    isLoading: _saving,
    onPressed: _saving ? null : _pick,
  );
}
