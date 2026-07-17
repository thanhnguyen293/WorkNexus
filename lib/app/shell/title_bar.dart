import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/desktop_window_service.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/quick_settings_button.dart';
import '../../l10n/app_localizations.dart';

/// The custom 34px window title bar: draggable, hosts the app title, a sync
/// indicator, and Quick Settings. Native traffic-lights show on the left
/// (macOS), so we reserve room for them.
class TitleBar extends ConsumerWidget {
  const TitleBar({super.key, this.assignedCount});

  final int? assignedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n.of(context);
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
        if (assignedCount != null) ...[
          SizedBox(width: context.spacing.md),
          Text(
            '·',
            style: context.typography.caption.copyWith(color: c.textTertiary),
          ),
          SizedBox(width: context.spacing.md),
          Flexible(
            child: Text(
              l10n.assignedToYou(assignedCount!),
              overflow: TextOverflow.ellipsis,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ),
        ],
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
          // Reserve space for the macOS traffic-light buttons.
          if (DesktopWindowService.isDesktop) const SizedBox(width: 60),
          Expanded(
            child: DesktopWindowService.isDesktop
                ? DragToMoveArea(child: title)
                : title,
          ),
          _SyncIndicator(),
          SizedBox(width: context.spacing.lg),
          const QuickSettingsButton(),
        ],
      ),
    );

    return bar;
  }
}

class _SyncIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
        ),
        SizedBox(width: context.spacing.xs),
        Text(
          AppL10n.of(context).syncedAgo,
          style: context.typography.monoSm.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}
