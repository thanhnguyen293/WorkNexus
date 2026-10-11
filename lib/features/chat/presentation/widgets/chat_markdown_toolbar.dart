import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/markdown_format.dart';

/// Under the input while Markdown is on: formatting for the selection,
/// undo/redo and a taller input. Its buttons never take focus, so the
/// input keeps its selection while they are clicked.
class ChatMarkdownToolbar extends StatelessWidget {
  const ChatMarkdownToolbar({
    super.key,
    required this.onFormat,
    required this.undo,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final ValueChanged<MarkdownFormat> onFormat;
  final UndoHistoryController undo;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final formats = <(IconData, String, MarkdownFormat)>[
      (LucideIcons.bold300, l.chatFormatBold, MarkdownFormat.bold),
      (LucideIcons.italic300, l.chatFormatItalic, MarkdownFormat.italic),
      (
        LucideIcons.underline300,
        l.chatFormatUnderline,
        MarkdownFormat.underline,
      ),
      (
        LucideIcons.strikethrough300,
        l.chatFormatStrikethrough,
        MarkdownFormat.strikethrough,
      ),
      (LucideIcons.heading300, l.chatFormatHeading, MarkdownFormat.heading),
      (LucideIcons.code300, l.chatFormatCode, MarkdownFormat.code),
      (LucideIcons.textQuote300, l.chatFormatQuote, MarkdownFormat.quote),
      (
        LucideIcons.removeFormatting300,
        l.chatFormatClear,
        MarkdownFormat.clear,
      ),
      (LucideIcons.list300, l.chatFormatBulletList, MarkdownFormat.bulletList),
      (
        LucideIcons.listOrdered300,
        l.chatFormatNumberedList,
        MarkdownFormat.numberedList,
      ),
      (
        LucideIcons.listIndentIncrease300,
        l.chatFormatIndent,
        MarkdownFormat.indent,
      ),
      (
        LucideIcons.listIndentDecrease300,
        l.chatFormatOutdent,
        MarkdownFormat.outdent,
      ),
    ];
    return ExcludeFocus(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (icon, tooltip, format) in formats)
              _FormatButton(
                icon: icon,
                tooltip: tooltip,
                onPressed: () => onFormat(format),
              ),
            ValueListenableBuilder(
              valueListenable: undo,
              builder: (context, history, _) => Row(
                children: [
                  _FormatButton(
                    icon: LucideIcons.undo2300,
                    tooltip: l.chatUndo,
                    onPressed: history.canUndo ? undo.undo : null,
                  ),
                  _FormatButton(
                    icon: LucideIcons.redo2300,
                    tooltip: l.chatRedo,
                    onPressed: history.canRedo ? undo.redo : null,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: s.xl4,
              child: VerticalDivider(width: s.lg, color: context.colors.border),
            ),
            _FormatButton(
              icon: expanded
                  ? LucideIcons.minimize2300
                  : LucideIcons.maximize2300,
              tooltip: expanded ? l.chatComposerCollapse : l.chatComposerExpand,
              onPressed: onToggleExpanded,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: context.spacing.xl4,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: c.textSecondary,
        disabledForegroundColor: c.textTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
      ),
      icon: Icon(icon),
    );
  }
}
