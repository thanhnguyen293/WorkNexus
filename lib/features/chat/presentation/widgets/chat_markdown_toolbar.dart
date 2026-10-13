import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/markdown_format.dart';
import 'chat_composer_controller.dart';

/// Under the input while Markdown is on: formatting for the selection (lit
/// while the selection has it), undo/redo and a taller input. Its buttons
/// never take focus, so the input keeps its selection while they are
/// clicked.
class ChatMarkdownToolbar extends StatelessWidget {
  const ChatMarkdownToolbar({
    super.key,
    required this.controller,
    required this.onFormat,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final ChatComposerController controller;
  final ValueChanged<MarkdownFormat> onFormat;
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
    final quill = controller.quill;
    return ExcludeFocus(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ListenableBuilder(
          listenable: quill,
          builder: (context, _) => Row(
            children: [
              for (final (icon, tooltip, format) in formats)
                AppIconButton(
                  icon: icon,
                  tooltip: tooltip,
                  selected: controller.isOn(format),
                  onPressed: () => onFormat(format),
                ),
              AppIconButton(
                icon: LucideIcons.undo2300,
                tooltip: l.chatUndo,
                onPressed: quill.hasUndo ? quill.undo : null,
              ),
              AppIconButton(
                icon: LucideIcons.redo2300,
                tooltip: l.chatRedo,
                onPressed: quill.hasRedo ? quill.redo : null,
              ),
              SizedBox(
                height: s.xl4,
                child: VerticalDivider(
                  width: s.lg,
                  color: context.colors.border,
                ),
              ),
              AppIconButton(
                icon: expanded
                    ? LucideIcons.minimize2300
                    : LucideIcons.maximize2300,
                tooltip: expanded
                    ? l.chatComposerCollapse
                    : l.chatComposerExpand,
                onPressed: onToggleExpanded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
