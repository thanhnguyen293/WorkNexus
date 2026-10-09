import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'app_dropdown.dart';
import 'quick_settings_color_control.dart';
import 'quick_settings_font_control.dart';
import 'quick_settings_parts.dart';
import 'quick_settings_radius_control.dart';
import 'quick_settings_segmented.dart';

/// Reactive controls for the app-wide language and appearance preferences,
/// grouped into sections and laid out by [QuickSettingsSidePanel].
class QuickSettingsPanel extends ConsumerWidget {
  const QuickSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final languages = {'en': l.english, 'vi': l.vietnamese};
    final sectionGap = SizedBox(height: context.spacing.xl5);
    return Column(
      key: const ValueKey<String>('quick-settings-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuickSettingsSection(
          title: l.appearance,
          children: [
            QuickSettingsField(
              label: l.theme,
              // null: follow the OS light/dark mode.
              control: QuickSettingsSegmented<AppThemeVariant?>(
                value: settings.themeFollowsSystem ? null : settings.variant,
                options: {
                  AppThemeVariant.light: l.themeLight,
                  AppThemeVariant.dark: l.themeDark,
                  AppThemeVariant.midnight: l.themeMidnight,
                  null: l.themeSystem,
                },
                onChanged: (v) => v == null
                    ? controller.setThemeFollowsSystem()
                    : controller.setVariant(v),
              ),
            ),
            QuickSettingsField(
              label: l.primaryColor,
              stacked: true,
              control: const QuickSettingsColorControl(),
            ),
            QuickSettingsField(
              label: l.surface,
              control: QuickSettingsSegmented<SurfaceStyle>(
                value: settings.surface,
                options: {
                  SurfaceStyle.flat: l.surfaceFlat,
                  SurfaceStyle.outline: l.surfaceOutline,
                },
                onChanged: controller.setSurface,
              ),
            ),
            QuickSettingsField(
              label: l.font,
              control: QuickSettingsFontControl(
                tooltip: l.chooseUiFont,
                systemLabel: l.systemFont,
                value: settings.fontFamily,
                onChanged: controller.setFontFamily,
              ),
            ),
            const QuickSettingsRadiusControl(),
            QuickSettingsSwitchField(
              label: l.companyTint,
              value: settings.companyTint,
              onChanged: controller.setCompanyTint,
            ),
          ],
        ),
        sectionGap,
        QuickSettingsSection(
          title: l.quickSettingsLayout,
          children: [
            QuickSettingsField(
              label: l.density,
              control: QuickSettingsSegmented<AppDensity>(
                value: settings.density,
                options: {
                  AppDensity.comfortable: l.densityComfortable,
                  AppDensity.compact: l.densityCompact,
                },
                onChanged: controller.setDensity,
              ),
            ),
            QuickSettingsField(
              label: l.detailLayout,
              control: QuickSettingsSegmented<DetailLayout>(
                value: settings.detailLayout,
                options: {
                  DetailLayout.twoPane: l.layoutTwoPane,
                  DetailLayout.document: l.layoutDocument,
                },
                onChanged: controller.setDetailLayout,
              ),
            ),
          ],
        ),
        sectionGap,
        QuickSettingsSection(
          title: l.quickSettingsRegion,
          children: [
            QuickSettingsField(
              label: l.language,
              control: AppDropdown<String>(
                value: settings.locale.languageCode,
                values: languages.keys.toList(),
                labelOf: (code) => languages[code] ?? code,
                onChanged: controller.setLanguageCode,
              ),
            ),
            QuickSettingsField(
              label: l.dateFormat,
              control: QuickSettingsSegmented<DateDisplayFormat>(
                value: settings.dateFormat,
                options: {
                  DateDisplayFormat.iso: l.dateFormatIso,
                  DateDisplayFormat.dmy: l.dateFormatDmy,
                  DateDisplayFormat.long: l.dateFormatLong,
                },
                onChanged: controller.setDateFormat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
