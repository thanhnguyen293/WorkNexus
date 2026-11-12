import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../debug/app_talker.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/dropped_files.dart';
import 'app_snack.dart';

/// Groups the [FileDropTarget]s under it: while files hover over any of
/// them, all show their hints — the one under the pointer highlighted — so
/// the user sees which area does what before letting go.
class FileDropZones extends StatefulWidget {
  const FileDropZones({super.key, required this.child});

  final Widget child;

  @override
  State<FileDropZones> createState() => _FileDropZonesState();
}

class _FileDropZonesState extends State<FileDropZones> {
  /// How many targets of the group files hover over (0 or 1, briefly 2 while
  /// moving between them).
  final _hovering = ValueNotifier<int>(0);

  @override
  void dispose() {
    _hovering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _DropZonesScope(notifier: _hovering, child: widget.child);
}

class _DropZonesScope extends InheritedNotifier<ValueNotifier<int>> {
  const _DropZonesScope({required super.notifier, required super.child});
}

/// Takes files dragged in from the OS onto [child]: while they hover, the
/// area is outlined with [hint] in its middle; on drop, [onDrop] gets their
/// contents (folders are skipped). Inside [FileDropZones] the hint also shows
/// while files hover over another target of the group.
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

  /// The group's hover count, when in a [FileDropZones].
  ValueNotifier<int>? _zones;

  @override
  void dispose() {
    final zones = _zones;
    // Told after the frame: the group's other targets may be mid-build.
    if (_hovering && zones != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => zones.value--);
    }
    super.dispose();
  }

  Future<void> _drop(DropDoneDetails details) async {
    _hover(false);
    // Logged step by step: on Windows a drop that does nothing gives no other
    // clue to which step it stopped at.
    appTalker.info('Drop: ${details.files.length} item(s) dropped');
    final List<DroppedFile> files;
    try {
      files = [
        for (final item in details.files)
          if (item is! DropItemDirectory)
            (name: item.name, bytes: await item.readAsBytes()),
      ];
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Drop: reading the files failed');
      if (mounted) {
        showAppSnack(
          context,
          AppL10n.of(context).dropFilesFailed,
          isError: true,
        );
      }
      return;
    }
    if (files.isNotEmpty && mounted) await widget.onDrop(files);
  }

  void _hover(bool hovering) {
    if (hovering == _hovering) return;
    appTalker.debug('Drop: files ${hovering ? 'over' : 'left'} the target');
    setState(() => _hovering = hovering);
    _zones?.value += hovering ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    _zones = context
        .dependOnInheritedWidgetOfExactType<_DropZonesScope>()
        ?.notifier;
    final on = widget.enabled && TickerMode.valuesOf(context).enabled;
    final shown = _hovering || (on && (_zones?.value ?? 0) > 0);
    return DropTarget(
      // desktop_drop hands a drop to every target whose box holds the point,
      // shown or not, and the shell keeps hidden sections laid out under the
      // visible one (their tickers off): a hidden chat would take a file
      // dropped on a ticket's comment. Only a target on screen takes drops.
      enable: on,
      onDragEntered: (_) => _hover(true),
      onDragExited: (_) => _hover(false),
      onDragDone: _drop,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: _DropOverlay(hint: widget.hint, active: _hovering),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The outline and hint shown while files hover: accent over the target
/// under the pointer, muted over the other targets of its group.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.hint, required this.active});

  final String hint;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final tint = active ? c.accent : c.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: active ? 0.08 : 0.04),
        border: Border.all(color: tint, width: 2),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(context.radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: s.sm,
            children: [
              Icon(LucideIcons.upload300, size: s.xl3, color: c.onAccent),
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
