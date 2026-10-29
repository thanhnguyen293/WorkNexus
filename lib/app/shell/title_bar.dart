import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/debug/debug_celebrate_button.dart';
import '../../core/platform/desktop_window_service.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/quick_settings_button.dart';
import '../../features/chat/presentation/widgets/chat_trust_debug_button.dart';
import '../../features/chat/presentation/widgets/chat_typing_debug_button.dart';
import 'desktop_window_buttons.dart';
import 'title_bar_search.dart';
import 'workspace_breadcrumb.dart';

/// The window title bar for the unified workspace shell (design §2, §8):
/// draggable, hosts [WorkspaceBreadcrumb] on the left, [TitleBarSearch] in
/// the center, and settings/window caption buttons on the right.
class TitleBar extends ConsumerWidget {
  const TitleBar({super.key, this.assignedCount});

  final int? assignedCount;

  /// Room for the macOS traffic-light buttons on the left, placed 19pt in
  /// by macos/Runner/MainFlutterWindow.swift.
  static const _macTrafficLightsWidth = 80.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final drawsCaption = DesktopWindowService.drawsCaptionButtons;
    final isDesktop = DesktopWindowService.isDesktop;
    // macOS draws its own traffic lights, centred in a bar of this height
    // (MainFlutterWindow.swift); the bar's content has to share that line.
    final isMac = isDesktop && !drawsCaption;

    return Container(
      height: isMac
          ? context.sizes.macTitleBarHeight
          : context.sizes.titleBarHeight,
      decoration: BoxDecoration(
        color: c.titleBar,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.only(left: s.md, right: drawsCaption ? 0 : s.md),
      child: Row(
        children: [
          if (isMac) const SizedBox(width: _macTrafficLightsWidth),
          const WorkspaceBreadcrumb(),
          SizedBox(width: s.md),
          Expanded(
            child: isDesktop
                ? const DragToMoveArea(child: Center(child: TitleBarSearch()))
                : const Center(child: TitleBarSearch()),
          ),
          SizedBox(width: s.md),
          const DebugCelebrateButton(),
          const ChatTypingDebugButton(),
          const ChatTrustDebugButton(),
          const QuickSettingsButton(),
          if (drawsCaption) ...[
            SizedBox(width: s.sm),
            const DesktopWindowButtons(),
          ],
        ],
      ),
    );
  }
}
