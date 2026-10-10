import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';

/// Writes a comment and posts it to the provider; the refreshed thread
/// (written to drift by the detail sync) then shows it.
///
/// ZenTao comments are HTML, so they get the rich editor — formatting plus
/// pasted / picked / dropped images uploaded to ZenTao. GitLab / GitHub take
/// Markdown, written as plain text.
class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({super.key, required this.ticket});

  final Ticket ticket;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _text = TextEditingController();
  final _html = HtmlEditingController();
  // ZenTao files uploads under a form id; one per composer is enough.
  final _uid = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  bool _posting = false;

  bool get _rich => widget.ticket.providerType == ProviderType.zentao;

  @override
  void dispose() {
    _text.dispose();
    _html.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage(Uint8List bytes, String name) async {
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .uploadImage(widget.ticket.accountId, _uid, bytes, name);
    return res is Ok<String> ? res.value : null;
  }

  Future<void> _post() async {
    final body = _rich ? _html.html : _text.text.trim();
    if (body.isEmpty || _posting) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).commentPostFailed;
    setState(() => _posting = true);
    final res = await getIt<SyncService>().postComment(widget.ticket, body);
    if (!mounted) return;
    setState(() => _posting = false);
    switch (res) {
      case Ok():
        _rich ? _html.quill.clear() : _text.clear();
      case Err():
        messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_rich)
          RichTextEditor(
            controller: _html,
            minHeight: 96,
            placeholder: l.writeCommentHint,
            imageLoader: (url) =>
                getIt<SyncService>().fetchTicketImage(widget.ticket, url),
            onUploadImage: _uploadImage,
          )
        else
          _PlainField(controller: _text, hint: l.writeCommentHint),
        SizedBox(height: context.spacing.md),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _posting,
          onPressed: _post,
          child: Text(l.commentAction),
        ),
      ],
    );
  }
}

/// The Markdown composer for providers whose comments are not HTML.
class _PlainField extends StatelessWidget {
  const _PlainField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 8,
      style: context.typography.body.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.surfaceSubtle,
        hintText: hint,
        hintStyle: context.typography.body.copyWith(color: c.textTertiary),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.accent),
      ),
    );
  }
}
