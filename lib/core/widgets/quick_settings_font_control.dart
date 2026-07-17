import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/fonts.dart';

/// Compact font picker used by the Quick Settings popover.
class QuickSettingsFontControl extends StatelessWidget {
  const QuickSettingsFontControl({
    required this.tooltip,
    required this.systemLabel,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String tooltip;
  final String systemLabel;
  final String value;
  final ValueChanged<String> onChanged;

  String _displayLabel(String font) => font == kSystemFont ? systemLabel : font;

  String? _previewFamily(BuildContext context, String font) {
    if (font != kSystemFont) return font;

    final theme = Theme.of(context);
    final platformTypography = Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: theme.colorScheme,
    );
    return (theme.brightness == Brightness.dark
            ? platformTypography.white
            : platformTypography.black)
        .bodyMedium
        ?.fontFamily;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: tooltip,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.md),
        side: context.hairlineSide,
      ),
      itemBuilder: (context) => [
        for (final font in kFontChoices)
          PopupMenuItem<String>(
            value: font,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _displayLabel(font),
                    style: context.typography.subtitle.copyWith(
                      fontFamily: _previewFamily(context, font),
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (font == value) Icon(Icons.check, color: c.accent),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          border: context.cardBorder,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayLabel(value),
              style: context.typography.captionStrong.copyWith(
                fontFamily: _previewFamily(context, value),
                color: c.textPrimary,
              ),
            ),
            SizedBox(width: context.spacing.xs),
            Icon(
              Icons.keyboard_arrow_down,
              size: context.spacing.xl3,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
