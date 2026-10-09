import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The app's dialog chrome: a rounded card with a title row (an optional
/// [headerTrailing] and a close button), the [child], and [actions] on a
/// footer under a hairline.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.headerTrailing,
    this.maxWidth,
    this.maxHeight,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? headerTrailing;
  final double? maxWidth;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? s.xl6 * 11,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl3, s.xl2, s.lg, s.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.typography.title.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  ?headerTrailing,
                  SizedBox(width: s.sm),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: AppL10n.of(context).cancel,
                    color: c.textTertiary,
                    icon: Icon(PhosphorIconsLight.x, size: s.xl3),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(child: child),
            Divider(height: 1, color: c.border),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.lg),
              child: Row(spacing: s.md, children: actions),
            ),
          ],
        ),
      ),
    );
  }
}
