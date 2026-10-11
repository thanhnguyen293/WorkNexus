import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fonts.dart';
import '../../domain/usecases/find_markdown_spans.dart';

/// The composer's text controller. With [markdown] on, the text is drawn
/// as it will show — bold, italic, headings… — and the syntax that makes
/// it (`**`, `*`, `# `…) is hidden; it stays in the text that is sent.
/// List and quote markers stay visible, faint.
class ChatMarkdownController extends TextEditingController {
  /// Hidden syntax: still in the text (the caret steps over it), drawn
  /// without ink and at a near-zero size so it takes no room.
  static const _hidden = TextStyle(color: Colors.transparent, fontSize: 0.01);

  bool _markdown = false;

  bool get markdown => _markdown;
  set markdown(bool on) {
    if (on == _markdown) return;
    _markdown = on;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    if (!_markdown || source.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    // Syntax is hidden, except a marker the caret stands in the middle of
    // (stepping through it with the arrow keys): that one shows, faint.
    final carets = [selection.baseOffset, selection.extentOffset];
    final spans = [
      for (final s in const FindMarkdownSpans()(
        source,
        caret: selection.isCollapsed ? selection.baseOffset : null,
      ))
        s.style == MarkdownSpanStyle.syntax &&
                carets.any((o) => s.start < o && o < s.end)
            ? (start: s.start, end: s.end, style: MarkdownSpanStyle.marker)
            : s,
    ];
    // What the IME is still composing (e.g. a Vietnamese word being typed)
    // keeps its underline, as in a plain field.
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final cuts = <int>{
      0,
      source.length,
      for (final s in spans) ...[s.start, s.end],
      if (composing.isValid) ...[composing.start, composing.end],
    }.toList()..sort();
    return TextSpan(
      style: style,
      children: [
        for (var i = 0; i + 1 < cuts.length; i++)
          TextSpan(
            text: source.substring(cuts[i], cuts[i + 1]),
            style: _styleFor(
              context,
              {
                for (final s in spans)
                  if (s.start <= cuts[i] && cuts[i + 1] <= s.end) s.style,
              },
              composing:
                  composing.isValid &&
                  composing.start <= cuts[i] &&
                  cuts[i + 1] <= composing.end,
            ),
          ),
      ],
    );
  }

  TextStyle? _styleFor(
    BuildContext context,
    Set<MarkdownSpanStyle> styles, {
    required bool composing,
  }) {
    if (styles.isEmpty && !composing) return null;
    if (styles.contains(MarkdownSpanStyle.syntax)) return _hidden;
    final c = context.colors;
    var style = const TextStyle();
    final lines = <TextDecoration>[
      if (composing || styles.contains(MarkdownSpanStyle.underline))
        TextDecoration.underline,
      if (styles.contains(MarkdownSpanStyle.strikethrough))
        TextDecoration.lineThrough,
    ];
    if (lines.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(lines));
    }
    if (styles.contains(MarkdownSpanStyle.heading)) {
      style = style.copyWith(
        fontSize: context.typography.title.fontSize,
        fontWeight: FontWeight.w600,
      );
    }
    if (styles.contains(MarkdownSpanStyle.bold)) {
      style = style.copyWith(fontWeight: FontWeight.w700);
    }
    if (styles.contains(MarkdownSpanStyle.italic)) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (styles.contains(MarkdownSpanStyle.code)) {
      style = style.copyWith(
        fontFamily: kMonoFont,
        backgroundColor: c.surfaceSubtle,
      );
    }
    if (styles.contains(MarkdownSpanStyle.quote)) {
      style = style.copyWith(color: c.textSecondary);
    }
    if (styles.contains(MarkdownSpanStyle.marker)) {
      style = style.copyWith(color: c.textTertiary);
    }
    return style;
  }
}
