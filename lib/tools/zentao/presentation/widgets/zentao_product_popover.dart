import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'zentao_popover_tab_button.dart';
import 'zentao_product_popover_list.dart';

/// Popover card content for selecting ZenTao products in Bugs header,
/// matching [ZenTaoExecutionPopover] styling (search, Mine/Others tabs, department badge).
class ZenTaoProductPopover extends ConsumerStatefulWidget {
  const ZenTaoProductPopover({
    super.key,
    required this.account,
    required this.onClose,
  });

  final Account account;
  final VoidCallback onClose;

  @override
  ConsumerState<ZenTaoProductPopover> createState() =>
      _ZenTaoProductPopoverState();
}

class _ZenTaoProductPopoverState extends ConsumerState<ZenTaoProductPopover> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  int _tab = 0; // 0 = Mine, 1 = Others

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);

    return AppPopupCard(
      child: SizedBox(
        width: 340,
        height: 400,
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: c.surfaceSubtle,
                  borderRadius: BorderRadius.circular(context.radii.sm),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.search300,
                      size: 14,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l.filterProducts,
                          hintStyle: context.typography.bodySm.copyWith(
                            color: c.textTertiary,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: context.typography.bodySm.copyWith(fontSize: 12),
                        onChanged: (val) => setState(() => _search = val),
                      ),
                    ),
                    if (_search.isNotEmpty)
                      InkWell(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        child: Icon(
                          LucideIcons.x300,
                          size: 13,
                          color: c.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Tabs: Mine (where you have work) vs Others
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  ZenTaoPopoverTabButton(
                    label: 'Mine',
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 12),
                  ZenTaoPopoverTabButton(
                    label: 'Others',
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),

            // Product list
            Expanded(
              child: ZenTaoProductPopoverList(
                account: widget.account,
                search: _search,
                tab: _tab,
                onClose: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
