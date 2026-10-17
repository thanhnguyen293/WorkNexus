import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

class WorkspaceColorChoice extends StatelessWidget {
  const WorkspaceColorChoice({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverSurface(
      onTap: onTap,
      width: context.sizes.controlSm + context.spacing.sm,
      height: context.sizes.controlSm,
      semanticLabel: '#${value.toRadixString(16).padLeft(8, '0').substring(2)}',
      selected: selected,
      color: Color(value),
      borderRadius: BorderRadius.circular(context.radii.sm),
      // The outline answers hover, not a tint: a tint would shift the colour.
      tintOnHover: false,
      border: Border.all(
        color: selected ? c.textPrimary : c.border,
        width: selected ? 2 : 1,
      ),
      hoverBorder: Border.all(
        color: selected ? c.textPrimary : c.borderStrong,
        width: selected ? 2 : 1,
      ),
    );
  }
}

class WorkspaceIconFilePicker extends StatelessWidget {
  const WorkspaceIconFilePicker({
    super.key,
    required this.colorValue,
    required this.shortCode,
    required this.iconKey,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final int colorValue;
  final String shortCode;
  final String iconKey;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final hasImage = workspaceIconImageBytes(iconKey) != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Row(
          children: [
            WorkspaceBadge(
              Color(colorValue),
              shortCode,
              big: true,
              iconKey: iconKey,
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Text(
                hasImage
                    ? (fileName ?? l.connectionsCustomIconSelected)
                    : l.connectionsNoFileSelected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.secondary.copyWith(
                  color: hasImage ? c.textPrimary : c.textTertiary,
                ),
              ),
            ),
            SizedBox(width: context.spacing.md),
            AppButton.outlinedNeutral(
              size: AppButtonSize.small,
              onPressed: onPick,
              child: Text(l.connectionsChooseFile),
            ),
            if (onClear != null) ...[
              SizedBox(width: context.spacing.sm),
              AppIconButton(
                icon: LucideIcons.x300,
                tooltip: l.connectionsRemoveCustomIcon,
                size: AppIconButtonSize.small,
                onPressed: onClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
