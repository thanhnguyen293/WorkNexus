import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/fonts.dart';
import '../../l10n/app_localizations.dart';

/// Reactive controls for the app-wide language and appearance preferences.
class QuickSettingsPanel extends ConsumerWidget {
  const QuickSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final maxHeight = math.min(
      context.spacing.xl6 * 12.5,
      MediaQuery.sizeOf(context).height,
    );

    return Container(
      key: const ValueKey<String>('quick-settings-panel'),
      width: context.spacing.xl6 * 8.5,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.all(context.spacing.xl2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.borderStrong),
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.22),
            blurRadius: context.spacing.xl6,
            offset: Offset(context.spacing.none, context.spacing.xl2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.quickSettings,
              style: context.typography.title.copyWith(color: c.textPrimary),
            ),
            SizedBox(height: context.spacing.xl),
            _SegmentedControl<String>(
              label: l.language,
              value: settings.locale.languageCode,
              options: {'en': l.english, 'vi': l.vietnamese},
              onChanged: controller.setLanguageCode,
            ),
            SizedBox(height: context.spacing.xl2),
            _SectionLabel(l.appearance),
            SizedBox(height: context.spacing.lg),
            _SegmentedControl<AppThemeVariant>(
              label: l.theme,
              value: settings.variant,
              options: {
                AppThemeVariant.light: l.themeLight,
                AppThemeVariant.dark: l.themeDark,
                AppThemeVariant.midnight: l.themeMidnight,
              },
              onChanged: controller.setVariant,
            ),
            SizedBox(height: context.spacing.xl),
            _SegmentedControl<SurfaceStyle>(
              label: l.surface,
              value: settings.surface,
              options: {
                SurfaceStyle.flat: l.surfaceFlat,
                SurfaceStyle.outline: l.surfaceOutline,
              },
              onChanged: controller.setSurface,
            ),
            SizedBox(height: context.spacing.xl),
            _SegmentedControl<AppDensity>(
              label: l.density,
              value: settings.density,
              options: {
                AppDensity.comfortable: l.densityComfortable,
                AppDensity.compact: l.densityCompact,
              },
              onChanged: controller.setDensity,
            ),
            SizedBox(height: context.spacing.xl),
            _SegmentedControl<bool>(
              label: l.companyTint,
              value: settings.companyTint,
              options: {false: l.settingOff, true: l.settingOn},
              onChanged: controller.setCompanyTint,
            ),
            SizedBox(height: context.spacing.xl),
            _FontControl(
              label: l.font,
              tooltip: l.chooseUiFont,
              value: settings.fontFamily,
              onChanged: controller.setFontFamily,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.typography.label.copyWith(
        color: context.colors.textTertiary,
      ),
    );
  }
}

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        SizedBox(height: context.spacing.sm),
        Container(
          padding: EdgeInsets.all(context.spacing.xxs),
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(context.radii.md),
          ),
          child: Wrap(
            children: [
              for (final entry in options.entries)
                TextButton(
                  onPressed: () => onChanged(entry.key),
                  style: TextButton.styleFrom(
                    backgroundColor: entry.key == value
                        ? c.selectionFill
                        : null,
                    foregroundColor: entry.key == value
                        ? c.accent
                        : c.textSecondary,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.lg,
                      vertical: context.spacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.radii.sm),
                    ),
                    textStyle: context.typography.bodySm.copyWith(
                      fontWeight: entry.key == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  child: Text(entry.value),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FontControl extends StatelessWidget {
  const _FontControl({
    required this.label,
    required this.tooltip,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String tooltip;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        SizedBox(height: context.spacing.sm),
        PopupMenuButton<String>(
          initialValue: value,
          onSelected: onChanged,
          tooltip: tooltip,
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
            side: BorderSide(color: c.border),
          ),
          itemBuilder: (context) => [
            for (final font in kFontChoices)
              PopupMenuItem<String>(
                value: font,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        font,
                        style: context.typography.subtitle.copyWith(
                          fontFamily: font,
                          fontWeight: FontWeight.w400,
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
            padding: EdgeInsets.fromLTRB(
              context.spacing.lg,
              context.spacing.sm,
              context.spacing.md,
              context.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(context.radii.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: context.typography.bodySmStrong.copyWith(
                    fontFamily: value,
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                Icon(Icons.keyboard_arrow_down, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
