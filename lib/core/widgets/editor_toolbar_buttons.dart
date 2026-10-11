import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import 'editor_color_button.dart';
import 'editor_link_button.dart';

/// The rich-text editor's toolbar buttons: the same Lucide glyphs as the
/// chat composer's formatting bar (in place of Quill's Material icons), in
/// the app's tones, with the app's own colour and link pickers.
QuillSimpleToolbarButtonOptions editorToolbarButtons(
  BuildContext context,
  QuillController quill,
) {
  final s = context.spacing;
  QuillToolbarToggleStyleButtonOptions toggle(IconData icon) =>
      QuillToolbarToggleStyleButtonOptions(iconData: icon);
  QuillToolbarIndentButtonOptions indent(IconData icon) =>
      QuillToolbarIndentButtonOptions(iconData: icon);
  QuillToolbarHistoryButtonOptions history(IconData icon) =>
      QuillToolbarHistoryButtonOptions(iconData: icon);
  return QuillSimpleToolbarButtonOptions(
    base: QuillToolbarBaseButtonOptions(
      iconSize: s.xl2,
      iconButtonFactor: 1.1,
      iconTheme: _iconTheme(context),
    ),
    undoHistory: history(LucideIcons.undo2300),
    redoHistory: history(LucideIcons.redo2300),
    bold: toggle(LucideIcons.bold300),
    italic: toggle(LucideIcons.italic300),
    underLine: toggle(LucideIcons.underline300),
    strikeThrough: toggle(LucideIcons.strikethrough300),
    inlineCode: toggle(LucideIcons.code300),
    listNumbers: toggle(LucideIcons.listOrdered300),
    listBullets: toggle(LucideIcons.list300),
    codeBlock: toggle(LucideIcons.squareCode300),
    quote: toggle(LucideIcons.textQuote300),
    toggleCheckList: const QuillToolbarToggleCheckListButtonOptions(
      iconData: LucideIcons.listChecks300,
    ),
    indentIncrease: indent(LucideIcons.listIndentIncrease300),
    indentDecrease: indent(LucideIcons.listIndentDecrease300),
    clearFormat: const QuillToolbarClearFormatButtonOptions(
      iconData: LucideIcons.removeFormatting300,
    ),
    // Swatch drop-downs in place of quill's Material dialog. Quill calls the
    // builder through a dynamic-typed function, so its parameters must be
    // untyped (typed ones fail at runtime).
    color: QuillToolbarColorButtonOptions(
      childBuilder: (Object? _, Object? _) => EditorColorButton(
        controller: quill,
        isBackground: false,
        iconSize: s.xl2 * 1.1,
      ),
    ),
    linkStyle: QuillToolbarLinkStyleButtonOptions(
      childBuilder: (Object? _, Object? _) =>
          EditorLinkButton(controller: quill, iconSize: s.xl2 * 1.1),
    ),
    backgroundColor: QuillToolbarColorButtonOptions(
      childBuilder: (Object? _, Object? _) => EditorColorButton(
        controller: quill,
        isBackground: true,
        iconSize: s.xl2 * 1.1,
      ),
    ),
  );
}

/// The box every editor toolbar button sits in — Quill's own and the app's
/// colour and link pickers alike — so their hover fills match: 40px, the
/// desktop size of a Material icon button, as a minimum (the paragraph-style
/// picker shares it and is wider).
ButtonStyle editorToolbarButtonStyle(BuildContext context) => ButtonStyle(
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.radii.sm),
    ),
  ),
  minimumSize: WidgetStatePropertyAll(Size.square(context.spacing.xl6)),
  padding: WidgetStatePropertyAll(EdgeInsets.all(context.spacing.sm)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  // Standard, not compact: compact density takes 8px off the minimum size.
  visualDensity: VisualDensity.standard,
);

/// Toolbar buttons in the app's tones: muted glyphs, and the active format
/// on a soft accent fill instead of Material's solid primary.
QuillIconTheme _iconTheme(BuildContext context) {
  final c = context.colors;
  final style = editorToolbarButtonStyle(context);
  return QuillIconTheme(
    iconButtonUnselectedData: IconButtonData(
      color: c.textSecondary,
      style: style,
    ),
    iconButtonSelectedData: IconButtonData(
      color: c.accent,
      style: style.copyWith(
        backgroundColor: WidgetStatePropertyAll(c.mixT(c.accent, 0.14)),
      ),
    ),
  );
}
