import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/image_fallback.dart';

/// Which structured section a run of the bug body belongs to.
enum _Kind { intro, steps, actual, expected }

class _Block {
  const _Block(this.kind, this.text);
  final _Kind kind;
  final String text;
}

/// Renders a bug's description. The body is a single text/HTML/markdown blob —
/// there are no separate step/actual/expected fields — so this does not parse
/// or restructure the content. It only *groups* it: when the blob contains the
/// well-known headings ("Steps to reproduce", "Actual result", "Expected
/// result", incl. VI), each run is shown under a styled card, still rendered as
/// plain markdown. Empty/absent sections are omitted, and any text that isn't
/// under a recognized heading is rendered as ordinary markdown, so no content
/// is ever dropped. A blob with none of the headings renders as one markdown
/// block.
class BugDescription extends StatelessWidget {
  const BugDescription({
    super.key,
    required this.body,
    this.imageLoader,
    this.imageFallback,
  });

  final String body;
  final ImageBytesLoader? imageLoader;
  final ImageFallback? imageFallback;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final blocks = _parse(body, l);
    final hasSections = blocks.any((b) => b.kind != _Kind.intro);

    if (!hasSections) {
      return MarkdownText(
        body,
        imageLoader: imageLoader,
        imageFallbackUrl: imageFallback?.resolveUrl,
        onOpenImage: imageFallback?.open,
      );
    }

    final children = <Widget>[];
    for (final b in blocks) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: context.spacing.xl2));
      }
      children.add(_block(context, l, b));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _block(BuildContext context, AppL10n l, _Block b) {
    switch (b.kind) {
      case _Kind.intro:
        return MarkdownText(
          b.text,
          imageLoader: imageLoader,
          imageFallbackUrl: imageFallback?.resolveUrl,
          onOpenImage: imageFallback?.open,
        );
      case _Kind.steps:
        return _Section(
          label: l.stepsToReproduce,
          labelColor: context.colors.textSecondary,
          text: b.text,
          imageLoader: imageLoader,
          imageFallback: imageFallback,
        );
      case _Kind.actual:
        return _Section(
          label: l.actualResult,
          labelColor: context.colors.error,
          accent: context.colors.error,
          text: b.text,
          imageLoader: imageLoader,
          imageFallback: imageFallback,
        );
      case _Kind.expected:
        return _Section(
          label: l.expectedResult,
          labelColor: context.colors.success,
          accent: context.colors.success,
          text: b.text,
          imageLoader: imageLoader,
          imageFallback: imageFallback,
        );
    }
  }

  /// Splits [body] into an intro plus typed runs by scanning for known heading
  /// lines. Every non-heading line is preserved in some block, so grouping
  /// never loses content; empty runs are dropped.
  List<_Block> _parse(String body, AppL10n l) {
    final blocks = <_Block>[];
    final buf = <String>[];
    var kind = _Kind.intro;

    void flush() {
      final text = buf.join('\n').trim();
      if (text.isNotEmpty) blocks.add(_Block(kind, text));
      buf.clear();
    }

    for (final line in body.split('\n')) {
      final header = _headerKind(line, l);
      if (header != null) {
        flush();
        kind = header;
      } else {
        buf.add(line);
      }
    }
    flush();
    return blocks;
  }

  _Kind? _headerKind(String line, AppL10n l) {
    final t = line
        .replaceAll(RegExp(r'[*_#`>]'), '')
        .trim()
        .replaceAll(RegExp(r'[:：]\s*$'), '')
        .trim()
        .toLowerCase();
    if (t.isEmpty) return null;

    const steps = {
      'steps to reproduce',
      'step to reproduce',
      'các bước tái hiện',
    };
    const actual = {
      'actual result',
      'actual results',
      'actual behavior',
      'actual behaviour',
      'kết quả thực tế',
    };
    const expected = {
      'expected result',
      'expected results',
      'expected behavior',
      'expected behaviour',
      'kết quả mong đợi',
    };

    if (t == l.stepsToReproduce.toLowerCase() || steps.contains(t)) {
      return _Kind.steps;
    }
    if (t == l.actualResult.toLowerCase() || actual.contains(t)) {
      return _Kind.actual;
    }
    if (t == l.expectedResult.toLowerCase() || expected.contains(t)) {
      return _Kind.expected;
    }
    return null;
  }
}

/// A titled card holding one section's markdown. [accent], when set, draws a
/// colored left edge (red for actual, green for expected); steps have none.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.labelColor,
    required this.text,
    this.accent,
    this.imageLoader,
    this.imageFallback,
  });

  final String label;
  final Color labelColor;
  final Color? accent;
  final String text;
  final ImageBytesLoader? imageLoader;
  final ImageFallback? imageFallback;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = this.accent;

    final card = MarkdownText(
      text,
      imageLoader: imageLoader,
      imageFallbackUrl: imageFallback?.resolveUrl,
      onOpenImage: imageFallback?.open,
    );
    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      child: card,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (accent != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(context.radii.xs),
                ),
              ),
              SizedBox(width: context.spacing.sm),
            ],
            Text(
              label,
              style: context.typography.bodyStrong.copyWith(color: labelColor),
            ),
          ],
        ),
        SizedBox(height: context.spacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.lg),
          child: accent == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceSubtle,
                    border: Border.all(color: c.border),
                  ),
                  child: padded,
                )
              // A colored left border can't combine with a borderRadius, so fill
              // the (clipped, rounded) card with the accent color and inset the
              // tinted body — the exposed accent stripe hugs the rounded edge.
              : ColoredBox(
                  color: accent,
                  child: Padding(
                    padding: EdgeInsets.only(left: context.borders.accent),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Opaque 6% tint over the card surface (design's
                        // color-mix), so the accent fill only shows as the strip.
                        color: c.mix(c.surfaceSubtle, accent, 0.06),
                        border: Border(
                          top: BorderSide(color: c.border),
                          right: BorderSide(color: c.border),
                          bottom: BorderSide(color: c.border),
                        ),
                      ),
                      child: padded,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
