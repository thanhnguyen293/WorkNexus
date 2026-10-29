import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A full page of the workspace (Overview, Integrations, Settings): the same
/// margins, content width and title on each, so moving between them nothing
/// jumps. The [title] and [subtitle] head the [children], with an optional
/// action on the right ([trailing]).
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return ColoredBox(
      color: c.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl5, s.xl4, s.xl5, s.xl5),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sizes.pageMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: context.typography.display.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: s.xs),
                            Text(
                              subtitle,
                              style: context.typography.bodySm.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[SizedBox(width: s.lg), trailing],
                  ],
                ),
                for (final child in children) ...[
                  SizedBox(height: s.xl4),
                  child,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
