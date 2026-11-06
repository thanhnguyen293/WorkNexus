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
import '../widgets/zentao_product_popover.dart';
import 'zentao_module_tree_section.dart';
import 'zentao_scope_picker_row.dart';

/// The Bugs side panel: the pinned products (and the open one), a picker for
/// any other, then the open product's module tree, which narrows the board
/// like ZenTao's own.
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
    // The pinned ones in their own order, so opening one never reorders
    // them; an open product that is not pinned shows above them.
    final rows = [
      ...products.where(
        (p) => p.id == location.scopeId && !pinned.contains(keyOf(p.id)),
      ),
      ...products.where((p) => pinned.contains(keyOf(p.id))),
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
              ZenTaoScopePickerRow(
                label: l.zentaoOtherProducts,
                popover: (close) =>
                    ZenTaoProductPopover(account: account, onClose: close),
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
