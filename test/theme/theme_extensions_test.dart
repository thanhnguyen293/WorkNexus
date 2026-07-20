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

  group('AppRadii scales the whole ramp from component', () {
    test('default component reproduces the historical fixed ramp', () {
      const r = AppRadii(); // component == kComponentRadiusDefault (8)
      expect(r.component, kComponentRadiusDefault);
      expect([r.xs, r.sm, r.md, r.card, r.lg, r.xl], [4, 6, 8, 10, 12, 20]);
    });

    test('a smaller component rounds every step down in lockstep', () {
      const r = AppRadii(component: 4);
      expect([r.xs, r.sm, r.md, r.card, r.lg, r.xl], [2, 3, 4, 5, 6, 10]);
    });

    test('zero component squares the ramp but keeps semantic constants', () {
      const r = AppRadii(component: 0);
      expect([r.xs, r.sm, r.md, r.card, r.lg, r.xl], everyElement(0));
      expect(r.none, 0);
      expect(r.dot, 2); // tiny status dots never square off
      expect(r.pill, 999); // pills/avatars stay fully round
    });

    test('componentRadius flows through buildAppTheme into AppRadii', () {
      final radii = buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
        componentRadius: 16,
      ).extension<AppRadii>()!;
      expect(radii.component, 16);
      expect([radii.md, radii.card, radii.xl], [16, 20, 40]);
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
