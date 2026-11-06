import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/navigation/rail_account_memory.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../core/widgets/app_rail_labeled_button.dart';
import '../../l10n/app_localizations.dart';

/// The rail places of the tools whose sections sit on the rail (ZenTao's
/// Tasks and Bugs; see `ToolModule.sectionsOnRail`): one button per section,
/// opening the tool's last-used account there. Nothing for a tool without an
/// account.
class RailSectionButtons extends ConsumerWidget {
  const RailSectionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final registry = ref.watch(toolRegistryProvider);
    final accounts = ref.watch(sortedActiveAccountsProvider);
    final nav = ref.watch(appNavProvider);
    final memory = ref.watch(railAccountMemoryProvider);
    final miniAppOnScreen = ref.watch(miniAppOnScreenProvider);

    final onScreen = switch (nav.rail) {
      AccountTarget(:final accountId) when !miniAppOnScreen =>
        accounts.where((a) => a.id == accountId).firstOrNull,
      _ => null,
    };

    return Column(
      children: [
        for (final module in registry.values)
          if (module.sectionsOnRail)
            if (accounts.where((a) => a.providerType == module.providerType)
                case final ofTool when ofTool.isNotEmpty)
              for (final section in module.sections)
                AppRailLabeledButton(
                  key: ValueKey('rail-section-${section.id.value}'),
                  leading: Icon(section.icon),
                  label: section.label(l),
                  selected:
                      onScreen?.providerType == module.providerType &&
                      nav.locations[onScreen?.id]?.section == section.id,
                  onTap: () {
                    final remembered = memory[module.providerType];
                    final id =
                        ofTool.any((a) => a.id == remembered) &&
                            remembered != null
                        ? remembered
                        : ofTool.first.id;
                    ref.read(appNavProvider.notifier)
                      ..selectAccount(id, module: module)
                      ..selectSection(section.id, sections: module.sections);
                  },
                ),
      ],
    );
  }
}
