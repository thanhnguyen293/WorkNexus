import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';

/// Which ZenTao account the Tasks / Bugs place shows, at the top of its side
/// panel: Tasks and Bugs sit on the rail, not one button per account. Only
/// with two accounts or more; switching keeps the place (Tasks or Bugs).
class ZenTaoAccountSwitcher extends ConsumerWidget {
  const ZenTaoAccountSwitcher({
    super.key,
    required this.account,
    required this.section,
    required this.sections,
  });

  final Account account;
  final SectionId section;
  final List<ToolSection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = [
      for (final a in ref.watch(sortedActiveAccountsProvider))
        if (a.providerType == ProviderType.zentao) a,
    ];
    if (accounts.length < 2) return const SizedBox.shrink();
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Padding(
        padding: EdgeInsets.all(s.sm),
        child: AppSegmentedTabs(
          tabs: [
            for (final a in accounts)
              AppSegmentedTab(
                label: a.handle,
                active: a.id == account.id,
                onTap: () {
                  if (a.id == account.id) return;
                  ref.read(appNavProvider.notifier)
                    ..selectAccount(a.id)
                    ..selectSection(section, sections: sections);
                },
              ),
          ],
        ),
      ),
    );
  }
}
