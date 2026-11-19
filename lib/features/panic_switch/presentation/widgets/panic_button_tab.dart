import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/value_objects/panic_button_look.dart';
import 'panic_labels.dart';
import 'panic_switch_save.dart';

/// The "Floating button" tab: whether the button is shown and, while it
/// is, how it is set off, how big and how faded it is.
class PanicButtonTab extends ConsumerWidget {
  const PanicButtonTab({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    void save(PanicSwitchConfig Function(PanicSwitchConfig) change) =>
        savePanicSwitch(context, ref, change);
    return Column(
      children: [
        AppExpandableCardSection(
          title: l.panicSwitchOverlayLabel,
          hint: l.panicSwitchOverlayHint,
          trailing: Switch(
            value: config.overlayVisible,
            onChanged: (v) => save((c) => c.copyWith(overlayVisible: v)),
          ),
        ),
        if (config.overlayVisible) ...[
          AppExpandableCardSection(
            title: l.panicSwitchGestureLabel,
            hint: l.panicSwitchGestureHint,
            child: AppSegmentedTabs(
              tabs: [
                for (final g in PanicGesture.values)
                  AppSegmentedTab(
                    label: gestureLabel(l, g),
                    active: config.overlayGesture == g,
                    onTap: () => save((c) => c.copyWith(overlayGesture: g)),
                  ),
              ],
            ),
          ),
          AppExpandableCardSection(
            title: l.panicSwitchSizeLabel,
            hint: l.panicSwitchSizeHint,
            child: AppSegmentedTabs(
              tabs: [
                for (final (i, v) in PanicButtonChoices.sizes.indexed)
                  AppSegmentedTab(
                    label: [
                      l.panicSwitchSizeSmall,
                      l.panicSwitchSizeMedium,
                      l.panicSwitchSizeLarge,
                    ][i],
                    active: config.overlaySize == v,
                    onTap: () => save((c) => c.copyWith(overlaySize: v)),
                  ),
              ],
            ),
          ),
          AppExpandableCardSection(
            title: l.panicSwitchFadeLabel,
            hint: l.panicSwitchFadeHint,
            child: AppSegmentedTabs(
              tabs: [
                for (final (i, v) in PanicButtonChoices.opacities.indexed)
                  AppSegmentedTab(
                    label: [
                      l.panicSwitchFadeNone,
                      l.panicSwitchFadeLow,
                      l.panicSwitchFadeMid,
                      l.panicSwitchFadeHigh,
                    ][i],
                    active: config.overlayOpacity == v,
                    onTap: () => save((c) => c.copyWith(overlayOpacity: v)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
