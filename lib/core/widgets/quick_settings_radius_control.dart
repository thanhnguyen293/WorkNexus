import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'quick_settings_parts.dart';

/// Height of the slider row — trimmed below the default interactive dimension so
/// the quick-settings popover stays within its compact height budget.
const double _sliderRowHeight = 22;

/// A compact slider that drives the app-wide component corner radius, snapping
/// to a few presets. The value readout is a live [AppButton] preview whose
/// corners re-round as you drag.
class QuickSettingsRadiusControl extends ConsumerWidget {
  const QuickSettingsRadiusControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final radius = ref.watch(
      appSettingsProvider.select((s) => s.componentRadius),
    );
    final controller = ref.read(appSettingsProvider.notifier);

    return QuickSettingsField(
      label: l.cornerRadius,
      control: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: _sliderRowHeight,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: c.accent,
                  inactiveTrackColor: c.border,
                  thumbColor: c.accent,
                  overlayColor: c.mixT(c.accent, 0.12),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: s.md),
                ),
                // Snaps to the 5 [kComponentRadiusPresets] stops.
                child: Slider(
                  max: kComponentRadiusMax,
                  divisions: kComponentRadiusPresets.length - 1,
                  value: snapComponentRadius(radius),
                  onChanged: controller.setComponentRadius,
                ),
              ),
            ),
          ),
          SizedBox(width: s.sm),
          // Live preview: its corners re-round as you drag.
          AppButton.filled(
            size: AppButtonSize.xxSmall,
            onPressed: () {},
            child: Text('${radius.round()}'),
          ),
        ],
      ),
    );
  }
}
