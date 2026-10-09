import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/dropped_files.dart';

/// Takes files dragged in from the OS onto [child]: while they hover, the
/// area is outlined with [hint] in its middle; on drop, [onDrop] gets their
/// contents (folders are skipped).
class FileDropTarget extends StatefulWidget {
  const FileDropTarget({
    super.key,
    required this.hint,
    required this.onDrop,
    required this.child,
    this.enabled = true,
  });

  final String hint;
  final Future<void> Function(List<DroppedFile> files) onDrop;
  final Widget child;
  final bool enabled;

  @override
  State<FileDropTarget> createState() => _FileDropTargetState();
}

class _FileDropTargetState extends State<FileDropTarget> {
  bool _hovering = false;

  Future<void> _drop(DropDoneDetails details) async {
    setState(() => _hovering = false);
    final files = <DroppedFile>[
      for (final item in details.files)
        if (item is! DropItemDirectory)
          (name: item.name, bytes: await item.readAsBytes()),
    ];
    if (files.isNotEmpty && mounted) await widget.onDrop(files);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: _drop,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hovering ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: _DropOverlay(hint: widget.hint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accent outline and hint shown while files hover over the target.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        border: Border.all(color: c.accent, width: 2),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(context.radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: s.sm,
            children: [
              Icon(
                PhosphorIconsLight.uploadSimple,
                size: s.xl3,
                color: c.onAccent,
              ),
              Text(
                hint,
                style: context.typography.bodySmStrong.copyWith(
                  color: c.onAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
