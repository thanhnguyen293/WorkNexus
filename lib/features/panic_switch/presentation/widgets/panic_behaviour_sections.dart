import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import 'panic_switch_save.dart';

/// The debounce choices offered, in seconds.
const _debounceChoices = [15, 30, 60, 120, 300];

/// The Official tab's last row: the debounce.
class PanicBehaviourSections extends ConsumerWidget {
  const PanicBehaviourSections({super.key, required this.config});

  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    void save(PanicSwitchConfig Function(PanicSwitchConfig) change) =>
        savePanicSwitch(context, ref, change);
    return Column(
      children: [
        AppExpandableCardSection(
          title: l.panicSwitchDebounceLabel,
          hint: l.panicSwitchDebounceHint,
          child: AppSegmentedTabs(
            tabs: [
              for (final v in _debounceChoices)
                AppSegmentedTab(
                  label: l.panicSwitchSeconds(v),
                  active: config.debounceSeconds == v,
                  onTap: () => save((c) => c.copyWith(debounceSeconds: v)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
