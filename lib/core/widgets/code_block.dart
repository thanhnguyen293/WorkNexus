import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_icon_button.dart';

/// Selectable monospace code on a subtle boxed surface: Markdown code
/// fences and chat code messages.
///
/// With [collapsedLines], code longer than that shows only its first lines
/// until expanded, so a pasted file doesn't take over a chat thread.
class CodeBlock extends StatefulWidget {
  const CodeBlock(
    this.code, {
    super.key,
    required this.fontSize,
    this.collapsedLines,
  });

  final String code;
  final double fontSize;
  final int? collapsedLines;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = widget.code.split('\n');
    final limit = widget.collapsedLines;
    final collapsible = limit != null && lines.length > limit;
    final shown = collapsible && !_expanded
        ? lines.take(limit).join('\n')
        : widget.code;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(context.spacing.lg),
                child: SelectableText(
                  shown,
                  style: context.typography.mono.copyWith(
                    fontSize: widget.fontSize,
                    color: c.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
              Positioned(
                top: context.spacing.xs,
                right: context.spacing.xs,
                child: _CopyButton(widget.code),
              ),
            ],
          ),
          if (collapsible)
            _ToggleBar(
              expanded: _expanded,
              lineCount: lines.length,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ),
    );
  }
}

/// The expand / collapse strip: a footer of its own, ruled off from the code
/// so it doesn't read as part of the snippet.
class _ToggleBar extends StatelessWidget {
  const _ToggleBar({
    required this.expanded,
    required this.lineCount,
    required this.onTap,
  });

  final bool expanded;
  final int lineCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final style = context.typography.bodySm.copyWith(color: c.textSecondary);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: context.spacing.xl3,
                  color: c.textSecondary,
                ),
                SizedBox(width: context.spacing.xs),
                Text(
                  expanded
                      ? l.codeBlockCollapse
                      : l.codeBlockShowAll(lineCount),
                  style: style,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Copies the whole snippet (collapsed or not), then shows a check for a
/// moment as confirmation.
class _CopyButton extends StatefulWidget {
  const _CopyButton(this.code);

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    // Filled with the block's own surface so a long first line running
    // underneath doesn't show through the glyph.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: AppIconButton(
        icon: _copied ? LucideIcons.check300 : LucideIcons.copy300,
        size: AppIconButtonSize.small,
        color: _copied ? c.success : null,
        tooltip: _copied ? l.codeBlockCopied : l.codeBlockCopy,
        onPressed: _copy,
      ),
    );
  }
}
