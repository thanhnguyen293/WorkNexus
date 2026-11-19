import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/value_objects/panic_button_look.dart';
import 'panic_labels.dart';
import 'panic_switch_save.dart';

/// The debounce choices offered, in seconds.
const _debounceChoices = [15, 30, 60, 120, 300];

/// The settings few people change, folded away under "More settings": the
/// floating button (shown, gesture, size, fade), reacting at all, hiding
/// WorkNexus and the debounce. The defaults work as they are.
class PanicMoreSettings extends ConsumerStatefulWidget {
  const PanicMoreSettings({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  ConsumerState<PanicMoreSettings> createState() => _PanicMoreSettingsState();
}

class _PanicMoreSettingsState extends ConsumerState<PanicMoreSettings> {
  var _open = false;

  void _save(PanicSwitchConfig Function(PanicSwitchConfig) change) =>
      savePanicSwitch(context, ref, change);

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final config = widget.config;
    return Column(
      children: [
        InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: s.xl2, vertical: s.lg),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.panicSwitchMore,
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: AppMotion.base,
                  child: Icon(
                    LucideIcons.chevronDown300,
                    size: context.sizes.iconMd,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          AppExpandableCardSection(
            title: l.panicSwitchOverlayLabel,
            hint: l.panicSwitchOverlayHint,
            trailing: Switch(
              value: config.overlayVisible,
              onChanged: (v) => _save((c) => c.copyWith(overlayVisible: v)),
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
                      onTap: () => _save((c) => c.copyWith(overlayGesture: g)),
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
                      onTap: () => _save((c) => c.copyWith(overlaySize: v)),
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
                      onTap: () => _save((c) => c.copyWith(overlayOpacity: v)),
                    ),
                ],
              ),
            ),
          ],
          AppExpandableCardSection(
            title: l.panicSwitchReceiveLabel,
            hint: l.panicSwitchReceiveHint,
            trailing: Switch(
              value: config.enabled,
              onChanged: (v) => _save((c) => c.copyWith(enabled: v)),
            ),
          ),
          AppExpandableCardSection(
            title: l.panicSwitchHideSelfLabel,
            hint: l.panicSwitchHideSelfHint,
            trailing: Switch(
              value: config.hideSelf,
              onChanged: (v) => _save((c) => c.copyWith(hideSelf: v)),
            ),
          ),
          AppExpandableCardSection(
            title: l.panicSwitchDebounceLabel,
            hint: l.panicSwitchDebounceHint,
            child: AppSegmentedTabs(
              tabs: [
                for (final v in _debounceChoices)
                  AppSegmentedTab(
                    label: l.panicSwitchSeconds(v),
                    active: config.debounceSeconds == v,
                    onTap: () => _save((c) => c.copyWith(debounceSeconds: v)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
