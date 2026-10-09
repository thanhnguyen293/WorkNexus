import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

/// A ZenTao object's kind as a small tinted tile — a red bug, an accent task,
/// an info story — so mixed lists of bugs, tasks and stories scan by color.
/// Unknown kinds (projects, docs…) get a neutral glyph.
class ZenTaoKindIcon extends StatelessWidget {
  const ZenTaoKindIcon(this.objectType, {super.key, this.large = false});

  /// The ZenTao `objectType` code (`bug`, `task`, `story`, `todo`…).
  final String? objectType;

  /// Notifications and other two-line rows use the larger tile.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final (icon, color) = switch (objectType?.trim().toLowerCase()) {
      'bug' => (PhosphorIconsFill.bug, c.error),
      'task' => (PhosphorIconsFill.clipboardText, c.accent),
      'story' => (PhosphorIconsFill.bookOpenText, c.info),
      'todo' => (PhosphorIconsFill.listChecks, c.notice),
      'execution' || 'project' => (PhosphorIconsFill.kanban, c.caution),
      _ => (PhosphorIconsFill.bell, c.textTertiary),
    };
    final box = large ? s.xl6 * 0.8 : s.xl5 + s.xxs;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.mixT(color, 0.14),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Icon(icon, size: large ? s.xl3 : s.xl2, color: color),
    );
  }
}
