import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../util/link_url.dart';
import 'app_button.dart';
import 'app_dialog_frame.dart';
import 'connection_text_field.dart';

/// What the link dialog decided: the text to show and its link, or a null
/// [link] to take the link off.
typedef EditorLinkResult = ({String text, String? link});

/// Asks for a link's text and address. Pre-filled from the selection (or the
/// link under the cursor, which it then edits and can remove).
class EditorLinkDialog extends StatefulWidget {
  const EditorLinkDialog({super.key, required this.text, this.link});

  final String text;

  /// The link being edited; null when inserting a new one.
  final String? link;

  @override
  State<EditorLinkDialog> createState() => _EditorLinkDialogState();
}

class _EditorLinkDialogState extends State<EditorLinkDialog> {
  late final _text = TextEditingController(text: widget.text);
  late final _url = TextEditingController(text: widget.link ?? '');

  /// Only shown once a save was tried, so typing isn't flagged midway.
  bool _showError = false;

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final link = normalizeLinkUrl(_url.text);
    if (link == null) {
      setState(() => _showError = true);
      return;
    }
    final text = _text.text.trim();
    Navigator.pop<EditorLinkResult>(context, (
      text: text.isEmpty ? link : text,
      link: link,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final editing = widget.link != null;
    return AppDialogFrame(
      title: editing ? l.editorEditLink : l.editorInsertLink,
      maxWidth: s.xl6 * 12,
      actions: [
        if (editing)
          AppButton.textNeutral(
            onPressed: () => Navigator.pop<EditorLinkResult>(context, (
              text: widget.text,
              link: null,
            )),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: s.sm,
              children: [
                Icon(
                  LucideIcons.unlink300,
                  size: s.xl3,
                  color: context.colors.error,
                ),
                Text(
                  l.editorLinkRemove,
                  style: TextStyle(color: context.colors.error),
                ),
              ],
            ),
          ),
        const Spacer(),
        AppButton.textNeutral(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        AppButton.filled(onPressed: _save, child: Text(l.save)),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: s.lg,
          children: [
            ConnectionTextField(
              label: l.editorLinkUrl,
              controller: _url,
              hint: 'https://',
              autofocus: true,
              prefixIcon: LucideIcons.link300,
              errorText: _showError ? l.editorLinkInvalid : null,
              onChanged: (_) {
                if (_showError) setState(() => _showError = false);
              },
              onSubmitted: (_) => _save(),
            ),
            ConnectionTextField(
              label: l.editorLinkText,
              controller: _text,
              prefixIcon: LucideIcons.type300,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}
