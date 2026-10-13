import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fonts.dart';

/// Line height of the composer's text, which its row counts are sized by.
const double kChatEditorLineHeight = 1.4;

/// The composer's body text style.
TextStyle chatEditorBodyStyle(BuildContext context) =>
    DefaultTextStyle.of(context).style
        .merge(context.typography.body)
        .copyWith(
          color: context.colors.textPrimary,
          height: kChatEditorLineHeight,
          decoration: TextDecoration.none,
        );

/// How the composer draws formatting: the app's body text, compact blocks
/// (it is a message, not a page), headings and code as the message bubble
/// shows them.
DefaultStyles chatEditorStyles(BuildContext context) {
  final c = context.colors;
  final s = context.spacing;
  final type = context.typography;
  final body = chatEditorBodyStyle(context);
  const none = HorizontalSpacing.zero;
  const flat = VerticalSpacing.zero;
  final gap = VerticalSpacing(s.xs, 0);
  DefaultTextBlockStyle block(TextStyle style, [BoxDecoration? decoration]) =>
      DefaultTextBlockStyle(style, none, flat, flat, decoration);
  TextStyle heading(TextStyle size) =>
      body.copyWith(fontSize: size.fontSize, fontWeight: FontWeight.w600);
  final mono = body.copyWith(fontFamily: kMonoFont);
  return DefaultStyles(
    paragraph: block(body),
    placeHolder: block(body.copyWith(color: c.textTertiary)),
    h1: block(heading(type.title)),
    h2: block(heading(type.titleSm)),
    h3: block(heading(type.body)),
    inlineCode: InlineCodeStyle(
      style: mono,
      backgroundColor: c.surfaceSubtle,
      radius: Radius.circular(context.radii.sm),
    ),
    link: body.copyWith(color: c.accent),
    quote: DefaultTextBlockStyle(
      body.copyWith(color: c.textSecondary),
      HorizontalSpacing(s.md, 0),
      gap,
      flat,
      BoxDecoration(
        border: Border(
          left: BorderSide(color: c.border, width: s.xxs),
        ),
      ),
    ),
    code: DefaultTextBlockStyle(
      mono,
      HorizontalSpacing(s.sm, s.sm),
      gap,
      flat,
      BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
    ),
    lists: DefaultListBlockStyle(body, none, flat, flat, null, null),
    indent: block(body),
    align: block(body),
    leading: block(body),
  );
}
