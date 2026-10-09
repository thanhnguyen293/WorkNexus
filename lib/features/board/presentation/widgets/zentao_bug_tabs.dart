import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../board_providers.dart';
import 'board_view_tabs.dart';

/// The ZenTao bug-board tab strip (All / Unclosed): All adds the Closed column,
/// Unclosed (the default) leaves it off. The active tab shows a spinner while
/// the columns' first pages load.
class ZenTaoBugTabs extends ConsumerWidget {
  const ZenTaoBugTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final active = ref.watch(zentaoBugTabProvider);
    final slice = ref.watch(zentaoBugSliceProvider);

    // Rendered inline on the ChromeBar toolbar row (see BoardPage) — just the
    // tab strip; the toolbar owns the surrounding chrome.
    return BoardViewTabs(
      tabs: [
        for (final tab in const [
          ZenTaoBugBrowseType.all,
          ZenTaoBugBrowseType.unclosed,
        ])
          BoardViewTab(
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
  ZenTaoBugBrowseType.assignedToMe => l.assignedToMe,
  ZenTaoBugBrowseType.resolvedByMe => l.resolvedByMe,
  ZenTaoBugBrowseType.assignedByMe => l.bugTabAssignedByMe,
};
