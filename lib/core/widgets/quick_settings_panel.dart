import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'quick_settings_font_control.dart';

/// Reactive controls for the app-wide language and appearance preferences.
class QuickSettingsPanel extends ConsumerWidget {
  const QuickSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final panelWidth = context.spacing.xl6 * 7.5;
    final maxHeight = math.min(
      context.spacing.xl6 * 12.5,
      MediaQuery.sizeOf(context).height,
    );
    final availableWidth = math.max(
      context.spacing.none,
      MediaQuery.sizeOf(context).width - context.spacing.xl2,
    );

    return Container(
      key: const ValueKey<String>('quick-settings-panel'),
      width: math.min(panelWidth, availableWidth),
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.md),
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
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.quickSettings,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ),
            SizedBox(height: context.spacing.md),
            _SettingRow(
              label: l.language,
              control: _CompactSegmentedControl<String>(
                value: settings.locale.languageCode,
                options: {'en': l.english, 'vi': l.vietnamese},
                onChanged: controller.setLanguageCode,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            _SettingRow(
              label: l.theme,
              control: _CompactSegmentedControl<AppThemeVariant>(
                value: settings.variant,
                options: {
                  AppThemeVariant.light: l.themeLight,
                  AppThemeVariant.dark: l.themeDark,
                  AppThemeVariant.midnight: l.themeMidnight,
                },
                onChanged: controller.setVariant,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            _SettingRow(
              label: l.surface,
              control: _CompactSegmentedControl<SurfaceStyle>(
                value: settings.surface,
                options: {
                  SurfaceStyle.flat: l.surfaceFlat,
                  SurfaceStyle.outline: l.surfaceOutline,
                },
                onChanged: controller.setSurface,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            _SettingRow(
              label: l.density,
              control: _CompactSegmentedControl<AppDensity>(
                value: settings.density,
                options: {
                  AppDensity.comfortable: l.densityComfortable,
                  AppDensity.compact: l.densityCompact,
                },
                onChanged: controller.setDensity,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            _SettingRow(
              label: l.companyTint,
              control: _CompactSegmentedControl<bool>(
                value: settings.companyTint,
                options: {false: l.settingOff, true: l.settingOn},
                onChanged: controller.setCompanyTint,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            _SettingRow(
              label: l.font,
              control: QuickSettingsFontControl(
                tooltip: l.chooseUiFont,
                systemLabel: l.systemFont,
                value: settings.fontFamily,
                onChanged: controller.setFontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.control});

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: context.spacing.xl6 * 2 - context.spacing.xs,
          child: Text(
            label,
            style: context.typography.caption.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: control,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactSegmentedControl<T> extends StatelessWidget {
  const _CompactSegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.all(context.spacing.none),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: context.cardBorder,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in options.entries)
            TextButton(
              onPressed: () => onChanged(entry.key),
              style: TextButton.styleFrom(
                backgroundColor: entry.key == value ? c.selectionFill : null,
                foregroundColor: entry.key == value
                    ? c.accent
                    : c.textSecondary,
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.xs,
                  vertical: context.spacing.xxs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.radii.sm),
                ),
                textStyle: entry.key == value
                    ? context.typography.captionStrong
                    : context.typography.caption,
              ),
              child: Text(entry.value),
            ),
        ],
      ),
    );
  }
}
