import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/contrast.dart';

/// Every text role and every status ink is read as text somewhere (meta
/// lines, timestamps, status pills), so each must clear WCAG AA on every
/// surface it can sit on, in every theme.
void main() {
  for (final variant in AppThemeVariant.values) {
    test('text and status colours read at 4.5:1 ($variant)', () {
      final c = AppColors.fromPalette(AppPalette.of(variant));
      final surfaces = {
        'background': c.background,
        'surface': c.surface,
        'surfaceSubtle': c.surfaceSubtle,
        'card': c.card,
      };
      final inks = {
        'textPrimary': c.textPrimary,
        'textSecondary': c.textSecondary,
        'textTertiary': c.textTertiary,
        'accent': c.accent,
        'success': c.success,
        'warning': c.warning,
        'error': c.error,
        'info': c.info,
        'caution': c.caution,
        'notice': c.notice,
      };
      for (final ink in inks.entries) {
        for (final surface in surfaces.entries) {
          expect(
            contrastRatio(ink.value, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: '${ink.key} on ${surface.key}',
          );
        }
      }
    });
  }
}
