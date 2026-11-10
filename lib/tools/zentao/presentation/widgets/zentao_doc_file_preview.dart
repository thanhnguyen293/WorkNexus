import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/zentao_doc_providers.dart';
import '../util/zentao_file_preview.dart';
import 'zentao_doc_code_block.dart';

/// An attached file shown in place, under its row: Markdown rendered as a
/// page, other text as numbered code, an image as itself. Downloaded once,
/// when first shown.
class ZenTaoDocFilePreview extends ConsumerStatefulWidget {
  const ZenTaoDocFilePreview({
    super.key,
    required this.account,
    required this.file,
    required this.kind,
  });

  final Account account;
  final TicketAttachment file;
  final ZenTaoFilePreview kind;

  @override
  ConsumerState<ZenTaoDocFilePreview> createState() =>
      _ZenTaoDocFilePreviewState();
}

class _ZenTaoDocFilePreviewState extends ConsumerState<ZenTaoDocFilePreview> {
  late Future<Result<Uint8List>> _bytes = _load();

  Future<Result<Uint8List>> _load() => ref
      .read(zenTaoDocRepositoryProvider)
      .readFile(widget.account, widget.file);

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return FutureBuilder<Result<Uint8List>>(
      future: _bytes,
      builder: (context, snap) => switch (snap.data) {
        null => Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.xl5),
          child: const AppStateView.loading(compact: true),
        ),
        Err() => AppStateView.error(
          compact: true,
          title: l.docsPreviewFailed,
          onRetry: () => setState(() => _bytes = _load()),
        ),
        Ok(:final value) => _Shown(bytes: value, kind: widget.kind),
      },
    );
  }
}

class _Shown extends StatelessWidget {
  const _Shown({required this.bytes, required this.kind});

  final Uint8List bytes;
  final ZenTaoFilePreview kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    String text() => utf8.decode(bytes, allowMalformed: true);
    return switch (kind) {
      ZenTaoFilePreview.markdown => Container(
        width: double.infinity,
        padding: EdgeInsets.all(s.xl4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.radii.md),
          border: Border.all(color: c.border, width: context.borders.hairline),
        ),
        child: MarkdownText(
          text(),
          fontSize: t.prose.fontSize ?? 14,
          height: t.prose.height ?? 1.6,
          color: c.textPrimary,
        ),
      ),
      ZenTaoFilePreview.text => ZenTaoDocCodeBlock(
        text().replaceFirst(RegExp(r'\n+$'), ''),
        fontSize: (t.prose.fontSize ?? 14) - 1.5,
      ),
      ZenTaoFilePreview.image => ClipRRect(
        borderRadius: BorderRadius.circular(context.radii.md),
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
      ZenTaoFilePreview.none => const SizedBox.shrink(),
    };
  }
}
