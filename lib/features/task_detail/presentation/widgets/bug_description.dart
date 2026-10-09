import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_image.dart';
import '../../../../core/widgets/rich_body_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/bug_description_sections.dart';
import '../util/image_fallback.dart';

/// Renders a bug's description in its own format (HTML for ZenTao, Markdown
/// otherwise). The body is a single blob — there are no separate step / actual
/// / expected fields — so this does not restructure the content. It only
/// *groups* it: when the blob contains the well-known headings ("Steps to
/// reproduce", "Actual result", "Expected result", incl. VI and ZenTao's
/// template), each run is shown under a styled card. Text under no recognized
/// heading is shown as is, so no content is ever dropped; a blob with none of
/// the headings renders as one block.
class BugDescription extends StatelessWidget {
  const BugDescription({
    super.key,
    required this.body,
    this.html = false,
    this.imageLoader,
    this.imageFallback,
  });

  final String body;

  /// Whether [body] is HTML (see `isHtmlBody`).
  final bool html;
  final ImageBytesLoader? imageLoader;
  final ImageFallback? imageFallback;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final sections = splitBugDescription(
      body,
      html: html,
      labels: {
        l.stepsToReproduce: BugSectionKind.steps,
        l.actualResult: BugSectionKind.actual,
        l.expectedResult: BugSectionKind.expected,
      },
    );
    Widget content(String text) => RichBodyText(
      text,
      html: html,
      imageLoader: imageLoader,
      imageFallbackUrl: imageFallback?.resolveUrl,
      onOpenImage: imageFallback?.open,
    );
    if (sections.every((s) => s.kind == BugSectionKind.intro)) {
      return content(body);
    }
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) SizedBox(height: context.spacing.xl2),
          switch (section.kind) {
            BugSectionKind.intro => content(section.text),
            BugSectionKind.steps => _Section(
              label: l.stepsToReproduce,
              labelColor: c.textSecondary,
              child: content(section.text),
            ),
            BugSectionKind.actual => _Section(
              label: l.actualResult,
              labelColor: c.error,
              accent: c.error,
              child: content(section.text),
            ),
            BugSectionKind.expected => _Section(
              label: l.expectedResult,
              labelColor: c.success,
              accent: c.success,
              child: content(section.text),
            ),
          },
        ],
      ],
    );
  }
}

/// A titled card holding one section's content. [accent], when set, draws a
/// colored left edge (red for actual, green for expected); steps have none.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.labelColor,
    required this.child,
    this.accent,
  });

  final String label;
  final Color labelColor;
  final Color? accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = this.accent;

    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      child: child,
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
