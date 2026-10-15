import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'mini_app_icon.dart';

/// The icon field of the edit dialog: a preview and the ways to change it —
/// pick an image or take the site's own icon.
class MiniAppIconPicker extends StatelessWidget {
  const MiniAppIconPicker({
    super.key,
    required this.name,
    required this.iconPath,
    required this.busy,
    required this.onChoose,
    required this.onUseSite,
  });

  final String name;
  final String? iconPath;

  /// An icon is being fetched or copied in.
  final bool busy;
  final VoidCallback onChoose;
  final VoidCallback onUseSite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: s.sm,
      children: [
        Text(
          l.miniAppIcon,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        Row(
          spacing: s.xl,
          children: [
            Container(
              padding: EdgeInsets.all(s.md),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(context.radii.lg),
              ),
              child: busy
                  ? SizedBox.square(
                      dimension: s.xl6 - s.xl,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : DefaultTextStyle.merge(
                      style: context.typography.body.copyWith(
                        color: c.textPrimary,
                      ),
                      child: MiniAppIcon(
                        name: name,
                        iconPath: iconPath,
                        size: s.xl6 - s.xl,
                      ),
                    ),
            ),
            Expanded(
              child: Wrap(
                spacing: s.md,
                runSpacing: s.md,
                children: [
                  AppButton.outlined(
                    size: AppButtonSize.small,
                    icon: LucideIcons.image300,
                    onPressed: busy ? null : onChoose,
                    child: Text(l.miniAppIconChoose),
                  ),
                  AppButton.outlined(
                    size: AppButtonSize.small,
                    icon: LucideIcons.globe300,
                    onPressed: busy ? null : onUseSite,
                    child: Text(l.miniAppIconSite),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
