import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_execution_popover.dart';

/// ZenTao header breadcrumb quick-switcher (`Execution > Project / Execution ▾`).
/// Opens a compact popover with search and Mine/Others executions.
class ZenTaoExecutionSwitcher extends ConsumerStatefulWidget {
  const ZenTaoExecutionSwitcher({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<ZenTaoExecutionSwitcher> createState() =>
      _ZenTaoExecutionSwitcherState();
}

class _ZenTaoExecutionSwitcherState
    extends ConsumerState<ZenTaoExecutionSwitcher> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final execution = ref.watch(selectedZenTaoExecutionProvider);

    final title = execution != null
        ? execution.executionName
        : 'Select Project';

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        ZenTaoExecutionPopover(
          account: widget.account,
          onClose: _menuController.close,
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.sm,
              vertical: context.spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded, size: 15, color: c.accent),
                SizedBox(width: context.spacing.xs),
                Text(
                  'Project',
                  style: context.typography.bodySm.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                Text(
                  ' › ',
                  style: context.typography.bodySm.copyWith(
                    color: c.textTertiary,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySmStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: context.spacing.xs),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
