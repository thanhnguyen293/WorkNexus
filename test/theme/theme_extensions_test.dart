import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_borders.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_radii.dart';
import 'package:work_nexus/core/theme/app_spacing.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/theme/app_typography.dart';
import 'package:work_nexus/core/theme/fonts.dart';

void main() {
  group('buildAppTheme registers every ThemeExtension', () {
    for (final variant in AppThemeVariant.values) {
      test('variant $variant resolves all five extensions', () {
        final theme = buildAppTheme(
          variant: variant,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        );
        expect(theme.extension<AppColors>(), isNotNull);
        expect(theme.extension<AppTypography>(), isNotNull);
        expect(theme.extension<AppSpacing>(), isNotNull);
        expect(theme.extension<AppRadii>(), isNotNull);
        expect(theme.extension<AppBorders>(), isNotNull);
      });
    }

    test('surface style drives AppBorders.showOutline', () {
      AppBorders bordersFor(SurfaceStyle surface) => buildAppTheme(
        variant: AppThemeVariant.light,
        surface: surface,
        density: AppDensity.comfortable,
      ).extension<AppBorders>()!;
      expect(bordersFor(SurfaceStyle.flat).showOutline, isFalse);
      expect(bordersFor(SurfaceStyle.outline).showOutline, isTrue);
    });

    test('density drives AppSpacing.cardPadding', () {
      EdgeInsets padFor(AppDensity density) => buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: density,
      ).extension<AppSpacing>()!.cardPadding;
      expect(
        padFor(AppDensity.compact),
        isNot(equals(padFor(AppDensity.comfortable))),
      );
    });

    test('system font leaves the platform family unset', () {
      ThemeData themeFor(String fontFamily) => buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
        fontFamily: fontFamily,
      );

      expect(kSystemFont, '__system__');
      final systemFamily = themeFor(
        kSystemFont,
      ).textTheme.bodyMedium?.fontFamily;
      expect(systemFamily, isNot(kSansFont));
      expect(systemFamily, isNot(kSystemFont));
      expect(themeFor(kSansFont).textTheme.bodyMedium?.fontFamily, kSansFont);
      expect(themeFor('').textTheme.bodyMedium?.fontFamily, kSansFont);
    });

    test('system font follows Flutter platform typography', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final theme = buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
        fontFamily: kSystemFont,
      );
      final platformFamily = Typography.material2021(
        platform: TargetPlatform.macOS,
        colorScheme: theme.colorScheme,
      ).black.bodyMedium?.fontFamily;

      expect(theme.textTheme.bodyMedium?.fontFamily, platformFamily);
    });
  });

  group('AppColors maps palette roles', () {
    test('semantic roles come straight from the palette', () {
      final c = AppColors.fromPalette(AppPalette.light);
      expect(c.background, AppPalette.light.bg);
      expect(c.success, AppPalette.light.green);
      expect(c.error, AppPalette.light.red);
      expect(c.textPrimary, AppPalette.light.tx);
    });

    test('lerp interpolates colors between variants', () {
      final light = AppColors.fromPalette(AppPalette.light);
      final dark = AppColors.fromPalette(AppPalette.dark);
      final mid = light.lerp(dark, 0.5);
      expect(
        mid.background,
        Color.lerp(light.background, dark.background, 0.5),
      );
    });
  });
}
