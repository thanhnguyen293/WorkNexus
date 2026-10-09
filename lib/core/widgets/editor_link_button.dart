import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'editor_link_dialog.dart';

/// The rich-text toolbar's link button, opening [EditorLinkDialog] in place
/// of flutter_quill's Material one. Lit while the cursor is on a link.
class EditorLinkButton extends StatelessWidget {
  const EditorLinkButton({
    super.key,
    required this.controller,
    required this.iconSize,
  });

  final QuillController controller;
  final double iconSize;

  Future<void> _open(BuildContext context) async {
    final current = QuillTextLink.prepare(controller);
    final result = await showDialog<EditorLinkResult>(
      context: context,
      builder: (_) => EditorLinkDialog(text: current.text, link: current.link),
    );
    if (result == null) return;
    QuillTextLink(result.text, result.link).submit(controller);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = QuillTextLink.isSelected(controller);
    return IconButton(
      tooltip: on
          ? AppL10n.of(context).editorEditLink
          : AppL10n.of(context).editorInsertLink,
      iconSize: iconSize,
      color: on ? c.accent : c.textSecondary,
      style: ButtonStyle(
        backgroundColor: on
            ? WidgetStatePropertyAll(c.mixT(c.accent, 0.14))
            : null,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
        ),
      ),
      onPressed: () => _open(context),
      icon: const Icon(PhosphorIconsLight.link),
    );
  }
}
