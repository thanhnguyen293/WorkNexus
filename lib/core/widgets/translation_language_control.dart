import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/translation_languages.dart';

/// Compact picker for the ticket **translation target language** (flag + native
/// name). Mirrors [QuickSettingsFontControl]: stateless, driven by [value] +
/// [onChanged], so callers own the persisted setting.
class TranslationLanguageControl extends StatelessWidget {
  const TranslationLanguageControl({
    required this.value,
    required this.onChanged,
    this.tooltip,
    super.key,
  });

  /// Selected language code (from [kTranslationLanguages]).
  final String value;
  final ValueChanged<String> onChanged;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = translationLanguageFor(value);
    return PopupMenuButton<String>(
      initialValue: selected.code,
      onSelected: onChanged,
      tooltip: tooltip ?? '',
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.md),
        side: context.hairlineSide,
      ),
      itemBuilder: (context) => [
        for (final lang in kTranslationLanguages)
          PopupMenuItem<String>(
            value: lang.code,
            height: context.spacing.xl6,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
            child: Row(
              children: [
                Text(lang.flag, style: context.typography.subtitle),
                SizedBox(width: context.spacing.lg),
                Expanded(
                  child: Text(
                    lang.nativeName,
                    style: context.typography.subtitle.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (lang.code == selected.code)
                  Icon(Icons.check, size: context.spacing.xl2, color: c.accent),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.md,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          border: context.cardBorder,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.flag, style: context.typography.captionStrong),
            SizedBox(width: context.spacing.xs),
            Text(
              selected.nativeName,
              style: context.typography.captionStrong.copyWith(
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
