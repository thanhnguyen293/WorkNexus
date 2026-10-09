import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/desktop_window_service.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/quick_settings_button.dart';
import '../../l10n/app_localizations.dart';

/// The custom 34px window title bar: draggable, hosts the app title and
/// Quick Settings. macOS traffic lights and Windows caption buttons stay clear.
class TitleBar extends ConsumerWidget {
  const TitleBar({super.key, this.assignedCount});

  final int? assignedCount;
  static const _windowsCaptionButtonsWidth = 46.0 * 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n.of(context);
    final isWindows = DesktopWindowService.isWindows;
    final title = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.appTitle,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySmStrong.copyWith(
              color: c.textPrimary,
            ),
          ),
        ),
        // if (assignedCount != null) ...[
        //   SizedBox(width: context.spacing.md),
        //   Text(
        //     '·',
        //     style: context.typography.caption.copyWith(color: c.textTertiary),
        //   ),
        //   SizedBox(width: context.spacing.md),
        //   Flexible(
        //     child: Text(
        //       l10n.assignedToYou(assignedCount!),
        //       overflow: TextOverflow.ellipsis,
        //       style: context.typography.caption.copyWith(color: c.textTertiary),
        //     ),
        //   ),
        // ],
      ],
    );
    final bar = Container(
      height: 34,
      decoration: BoxDecoration(
        color: c.titleBar,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      child: Row(
        children: [
          if (DesktopWindowService.isDesktop)
            SizedBox(
              width: isWindows
                  ? _windowsCaptionButtonsWidth +
                        context.spacing.lg * 2 +
                        context.spacing.xl5 +
                        context.spacing.xs
                  : 60.0,
            ),
          Expanded(
            child: DesktopWindowService.isDesktop
                ? DragToMoveArea(child: title)
                : title,
          ),
          SizedBox(width: context.spacing.lg),
          const QuickSettingsButton(),
          if (isWindows) ...[
            SizedBox(width: context.spacing.lg),
            SizedBox(
              width: _windowsCaptionButtonsWidth,
              child: WindowCaption(
                backgroundColor: c.titleBar,
                brightness: Theme.of(context).brightness,
              ),
            ),
          ],
        ],
      ),
    );

    return bar;
  }
}
