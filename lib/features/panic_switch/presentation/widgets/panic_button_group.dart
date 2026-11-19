import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/value_objects/panic_button_look.dart';
import 'panic_group_label.dart';
import 'panic_labels.dart';
import 'panic_switch_save.dart';

/// The floating button: shown or not, and — while shown — how it is set off,
/// how big and how faded it is.
class PanicButtonGroup extends ConsumerWidget {
  const PanicButtonGroup({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    void save(PanicSwitchConfig Function(PanicSwitchConfig) change) =>
        savePanicSwitch(context, ref, change);
    final sizeNames = [
      l.panicSwitchSizeSmall,
      l.panicSwitchSizeMedium,
      l.panicSwitchSizeLarge,
    ];
    final fadeNames = [
      l.panicSwitchFadeNone,
      l.panicSwitchFadeLow,
      l.panicSwitchFadeMid,
      l.panicSwitchFadeHigh,
    ];
    return Column(
      children: [
        PanicGroupLabel(l.panicSwitchSectionButton),
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
                for (final (i, size) in PanicButtonChoices.sizes.indexed)
                  AppSegmentedTab(
                    label: sizeNames[i],
                    active: config.overlaySize == size,
                    onTap: () => save((c) => c.copyWith(overlaySize: size)),
                  ),
              ],
            ),
          ),
          AppExpandableCardSection(
            title: l.panicSwitchFadeLabel,
            hint: l.panicSwitchFadeHint,
            child: AppSegmentedTabs(
              tabs: [
                for (final (i, o) in PanicButtonChoices.opacities.indexed)
                  AppSegmentedTab(
                    label: fadeNames[i],
                    active: config.overlayOpacity == o,
                    onTap: () => save((c) => c.copyWith(overlayOpacity: o)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
