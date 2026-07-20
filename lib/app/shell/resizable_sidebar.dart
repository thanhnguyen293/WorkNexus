import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../features/board/presentation/widgets/sidebar.dart';

/// Bounds (logical px) the sidebar can be dragged between.
const double _kSidebarMinWidth = 220.0;
const double _kSidebarMaxWidth = 520.0;

/// Width of the invisible grab strip on the sidebar's right edge.
const double _kHandleWidth = 8.0;

/// Width of the accent line shown while the grab strip is hovered/dragged.
const double _kHandleLineWidth = 2.0;

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

    return Row(
      children: [
        SizedBox(width: width, child: const SidebarView()),
        _ResizeHandle(
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
      ],
    );
  }
}

/// The thin, full-height grab strip. Shows a resize cursor on hover and a subtle
/// accent line while hovered or dragging; forwards horizontal drag deltas.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({required this.onDelta, required this.onEnd});

  final ValueChanged<double> onDelta;
  final VoidCallback onEnd;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDelta(d.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onEnd();
        },
        child: SizedBox(
          width: _kHandleWidth,
          height: double.infinity,
          child: Center(
            child: SizedBox(
              width: _kHandleLineWidth,
              height: double.infinity,
              child: active ? ColoredBox(color: c.accent) : null,
            ),
          ),
        ),
      ),
    );
  }
}
