import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/fonts.dart';
import '../theme/google_font_families.dart';
import 'app_dropdown.dart';

/// Font picker for Quick Settings; each font previews in its own face.
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
    // google-fonts-backed families (Geist Mono) resolve to a
    // generated family name; bundled/system families are used by name.
    final googleFont = kGoogleFontFamilies[font];
    if (googleFont != null) return googleFont.style().fontFamily;
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
    return AppDropdown<String>(
      value: value,
      values: kFontChoices,
      labelOf: _displayLabel,
      fontFamilyOf: _previewFamily,
      tooltip: tooltip,
      onChanged: onChanged,
    );
  }
}
