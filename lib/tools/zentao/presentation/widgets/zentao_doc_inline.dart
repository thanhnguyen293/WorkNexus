import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'zentao_doc_reader_controller.dart';

/// The highlight behind a find match: soft for every match, strong for the
/// current one.
Color zenTaoFindFill(BuildContext context, {required bool current}) {
  final c = context.colors;
  return c.mix(c.card, c.warning, current ? 0.6 : 0.25);
}

/// A find match in the page's text, keyed so the reader can scroll to it;
/// it follows the current match itself (no page rebuild).
class ZenTaoDocFindMark extends StatelessWidget {
  const ZenTaoDocFindMark({
    super.key,
    required this.text,
    required this.index,
    required this.style,
    required this.reader,
  });

  final String text;
  final int index;
  final TextStyle style;
  final ZenTaoDocReader reader;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: reader.current,
    builder: (context, current, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: zenTaoFindFill(context, current: current == index),
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(text, style: style),
    ),
  );
}

/// Inline code, as ZenTao's web draws it: a bordered mono chip. Holding a
/// find match ([matches]), the chip is highlighted.
class ZenTaoDocInlineCode extends StatelessWidget {
  const ZenTaoDocInlineCode(
    this.code, {
    super.key,
    required this.fontSize,
    required this.reader,
    this.matches = const [],
  });

  final String code;
  final double fontSize;
  final ZenTaoDocReader reader;
  final List<int> matches;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: reader.current,
    builder: (context, current, _) {
      final c = context.colors;
      final s = context.spacing;
      return Container(
        margin: EdgeInsets.symmetric(horizontal: s.xxs),
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
        decoration: BoxDecoration(
          color: matches.isEmpty
              ? c.surfaceSubtle
              : zenTaoFindFill(context, current: matches.contains(current)),
          borderRadius: BorderRadius.circular(context.radii.xs),
          border: Border.all(color: c.border, width: context.borders.hairline),
        ),
        child: Text(
          code,
          style: context.typography.mono.copyWith(
            fontSize: fontSize,
            color: c.textPrimary,
          ),
        ),
      );
    },
  );
}
