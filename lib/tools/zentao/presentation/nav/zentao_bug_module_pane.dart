import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../providers/zentao_board_providers.dart';
import '../util/select_bug_board_product.dart';
import 'zentao_module_tree_section.dart';

/// The Bugs side panel: the open product and the pinned ones (any other
/// product is a pick away in the header's product switcher), then the open
/// product's module tree, which narrows the board like ZenTao's own.
class ZentaoBugModulePane extends ConsumerWidget {
  const ZentaoBugModulePane({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final products =
        ref.watch(zentaoProductsProvider(account.id)).asData?.value ?? const [];
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );
    String keyOf(String productId) => '${account.id}:$productId';
    // The open product first, then the pinned ones.
    final rows = [
      ...products.where((p) => p.id == location.scopeId),
      ...products.where(
        (p) => p.id != location.scopeId && pinned.contains(keyOf(p.id)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(s.sm, s.xs, s.sm, s.lg),
            children: [
              ScopeGroupHeader(title: l.zentaoProductsGroup),
              for (final p in rows)
                ScopeRow(
                  name: p.name,
                  icon: LucideIcons.package300,
                  selected: p.id == location.scopeId,
                  isPinned: pinned.contains(keyOf(p.id)),
                  onPinToggle: () => ref
                      .read(appSettingsProvider.notifier)
                      .togglePinnedProject(keyOf(p.id)),
                  onTap: () => selectBugBoardProduct(ref, p),
                ),
              SizedBox(height: s.sm),
              const ZenTaoModuleTreeSection(bugs: true),
            ],
          ),
        ),
        const ZenTaoHideEmptyModulesToggle(),
      ],
    );
  }
}
