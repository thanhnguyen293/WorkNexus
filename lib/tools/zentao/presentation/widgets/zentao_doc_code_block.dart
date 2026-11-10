import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/code_block.dart';

/// A code block in a ZenTao document, as ZenTao's web shows one: numbered
/// lines that never wrap — documents hold ASCII diagrams and aligned tables
/// whose columns a wrap would break — scrolling sideways when wider than the
/// page, with a copy button in the corner. Selectable through the reader's
/// selection area.
class ZenTaoDocCodeBlock extends StatefulWidget {
  const ZenTaoDocCodeBlock(this.code, {super.key, required this.fontSize});

  final String code;
  final double fontSize;

  @override
  State<ZenTaoDocCodeBlock> createState() => _ZenTaoDocCodeBlockState();
}

class _ZenTaoDocCodeBlockState extends State<ZenTaoDocCodeBlock> {
  final _scroll = ScrollController();

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(s.xl, s.lg, s.md, s.lg),
                // Left out of a selection: copying lines copies the code only.
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
                    padding: EdgeInsets.fromLTRB(s.xs, s.lg, s.xl6, s.lg),
                    child: Text(widget.code, style: style),
                  ),
                ),
              ),
            ],
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
}
