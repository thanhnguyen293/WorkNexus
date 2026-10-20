import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_bug_streams.dart';

/// The ZenTao bug-board tab strip (All / Unclosed / Assigned to me): All adds
/// the Closed column, Unclosed (the default) leaves it off, Assigned to me
/// loads only the bugs assigned to the user. The active tab shows a spinner
/// while the columns' first pages load.
class ZenTaoBugTabs extends ConsumerWidget {
  const ZenTaoBugTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final active = ref.watch(zentaoBugTabProvider);
    final slice = ref.watch(zentaoBugSliceProvider);

    // Rendered inline on the ChromeBar toolbar row (see BoardPage) — just the
    // tab strip; the toolbar owns the surrounding chrome.
    return AppSegmentedTabs(
      tabs: [
        for (final tab in const [
          ZenTaoBugBrowseType.all,
          ZenTaoBugBrowseType.unclosed,
          ZenTaoBugBrowseType.relatedToMe,
        ])
          AppSegmentedTab(
            label: _label(l, tab),
            active: tab == active,
            loading: tab == active && slice.isLoading,
            onTap: () => ref.read(zentaoBugTabProvider.notifier).set(tab),
          ),
      ],
    );
  }
}

String _label(AppL10n l, ZenTaoBugBrowseType tab) => switch (tab) {
  ZenTaoBugBrowseType.all => l.bugTabAll,
  ZenTaoBugBrowseType.unclosed => l.bugTabUnclosed,
  ZenTaoBugBrowseType.reportedByMe => l.bugTabReportedByMe,
  ZenTaoBugBrowseType.relatedToMe => l.relatedToMe,
  ZenTaoBugBrowseType.resolvedByMe => l.resolvedByMe,
  ZenTaoBugBrowseType.assignedByMe => l.bugTabAssignedByMe,
};
