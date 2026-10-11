import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_icon_button.dart';

/// The app's dialog chrome: a rounded card with a title row (an optional
/// [headerTrailing] and a close button), the [child], and [actions] on a
/// footer under a hairline (no footer when [actions] is empty).
///
/// Width defaults to `sizes.dialogMd`; pass `sizes.dialogSm` / `dialogLg`
/// rather than a literal. Esc closes it (the dialog route handles that); wire
/// `onSubmitted` on its fields so Enter runs the primary action.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.headerTrailing,
    this.leadingIcon,
    this.maxWidth,
    this.maxHeight,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? headerTrailing;

  /// A glyph before the title, tinted with the accent (e.g. the action a
  /// dialog performs).
  final IconData? leadingIcon;
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
          maxWidth: maxWidth ?? context.sizes.dialogMd,
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
                  if (leadingIcon case final icon?) ...[
                    Icon(icon, size: context.sizes.iconLg, color: c.accent),
                    SizedBox(width: s.md),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.title.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  ?headerTrailing,
                  SizedBox(width: s.sm),
                  AppIconButton(
                    icon: LucideIcons.x300,
                    tooltip: AppL10n.of(context).close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(child: child),
            if (actions.isNotEmpty) ...[
              Divider(height: 1, color: c.border),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: s.xl3,
                  vertical: s.lg,
                ),
                child: Row(spacing: s.md, children: actions),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
