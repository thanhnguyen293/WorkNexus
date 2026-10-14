import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/widgets/resize_handle.dart';
import '../../features/board/presentation/widgets/sidebar.dart';

/// Bounds (logical px) the sidebar can be dragged between.
const double _kSidebarMinWidth = 220.0;
const double _kSidebarMaxWidth = 520.0;

/// Wraps [SidebarView] with a draggable right edge so the left rail can be
/// resized. The chosen width lives in [AppSettings.sidebarWidth] and is written
/// once per drag gesture (on release), so it survives restarts; during a drag
/// the width is tracked locally for smoothness.
class ResizableSidebar extends ConsumerStatefulWidget {
  const ResizableSidebar({super.key});

  @override
  ConsumerState<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends ConsumerState<ResizableSidebar> {
  /// Non-null only mid-drag; otherwise the width comes from settings.
  double? _dragWidth;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(appSettingsProvider.select((s) => s.sidebarWidth));
    final width = (_dragWidth ?? saved)
        .clamp(_kSidebarMinWidth, _kSidebarMaxWidth)
        .toDouble();

    // The grab strip lies over the sidebar's right edge instead of beside it,
    // so the sidebar meets the board with just its hairline between them.
    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SidebarView(),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: kResizeHandleWidth,
            child: ResizeHandle(
              onDelta: (dx) => setState(() {
                final current = _dragWidth ?? saved;
                _dragWidth = (current + dx)
                    .clamp(_kSidebarMinWidth, _kSidebarMaxWidth)
                    .toDouble();
              }),
              onEnd: () {
                final next = _dragWidth;
                _dragWidth = null;
                if (next != null) {
                  ref.read(appSettingsProvider.notifier).setSidebarWidth(next);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
