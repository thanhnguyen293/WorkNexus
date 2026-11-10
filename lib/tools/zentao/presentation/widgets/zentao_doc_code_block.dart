import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/code_block.dart';
import 'zentao_doc_inline.dart';
import 'zentao_doc_reader_controller.dart';

/// A code block in a ZenTao document, as ZenTao's web shows one: numbered
/// lines that never wrap — documents hold ASCII diagrams and aligned tables
/// whose columns a wrap would break — scrolling sideways when wider than the
/// page, with a copy button in the corner. Selectable through the reader's
/// selection area. Find [matches] in it are highlighted, the [reader]'s
/// current one strongest.
class ZenTaoDocCodeBlock extends StatefulWidget {
  const ZenTaoDocCodeBlock(
    this.code, {
    super.key,
    required this.fontSize,
    this.reader,
    this.matches = const [],
  });

  final String code;
  final double fontSize;
  final ZenTaoDocReader? reader;

  /// Find matches as their index and range in [code].
  final List<({int index, int start, int end})> matches;

  @override
  State<ZenTaoDocCodeBlock> createState() => _ZenTaoDocCodeBlockState();
}

class _ZenTaoDocCodeBlockState extends State<ZenTaoDocCodeBlock> {
  // Not kept in PageStorage: without a key of its own this sideways scroll
  // would share the page's storage slot, read back the page's vertical
  // offset and open every block scrolled to its far end.
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final lines = widget.code.split('\n');
    // One style for the code and its numbers, so each number sits on its line.
    final style = context.typography.mono.copyWith(
      fontSize: widget.fontSize,
      height: 1.6,
      color: c.textPrimary,
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: c.border, width: context.borders.hairline),
      ),
      child: Stack(
        children: [
          // Intrinsic height: the gutter's band runs the block's full height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The gutter: its own tinted band, ruled off from the code,
                // so the numbers don't read as part of it.
                Container(
                  padding: EdgeInsets.fromLTRB(s.lg, s.lg, s.md, s.lg),
                  decoration: BoxDecoration(
                    color: c.hoverFill,
                    border: Border(
                      right: BorderSide(
                        color: c.border,
                        width: context.borders.hairline,
                      ),
                    ),
                  ),
                  // Left out of a selection: copying lines copies the code
                  // only.
                  child: SelectionContainer.disabled(
                    child: Text(
                      [for (var i = 1; i <= lines.length; i++) '$i'].join('\n'),
                      textAlign: TextAlign.right,
                      style: style.copyWith(color: c.textTertiary),
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      // Room on the right for the copy button over line one.
                      padding: EdgeInsets.fromLTRB(s.md, s.lg, s.xl6, s.lg),
                      child: switch (widget.reader) {
                        final reader? when widget.matches.isNotEmpty =>
                          ValueListenableBuilder<int>(
                            valueListenable: reader.current,
                            builder: (context, current, _) => Text.rich(
                              _highlighted(context, style, current),
                              softWrap: false,
                            ),
                          ),
                        // No wrap: the gutter's intrinsic-height pass measures
                        // the code at the visible width, and wrapped lines
                        // there left an empty band under the block.
                        _ => Text(widget.code, style: style, softWrap: false),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: s.xs,
            right: s.xs,
            child: CodeCopyButton(widget.code),
          ),
        ],
      ),
    );
  }

  /// [ZenTaoDocCodeBlock.code] with its find matches on a highlight.
  TextSpan _highlighted(BuildContext context, TextStyle style, int current) {
    final code = widget.code;
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in widget.matches) {
      final start = m.start.clamp(at, code.length);
      final end = m.end.clamp(start, code.length);
      if (start > at) spans.add(TextSpan(text: code.substring(at, start)));
      if (end > start) {
        spans.add(
          TextSpan(
            text: code.substring(start, end),
            style: TextStyle(
              backgroundColor: zenTaoFindFill(
                context,
                current: m.index == current,
              ),
            ),
          ),
        );
      }
      at = end;
    }
    if (at < code.length) spans.add(TextSpan(text: code.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}
