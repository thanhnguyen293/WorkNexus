import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_snack.dart';
import '../widgets/hover_surface.dart';

/// Debug builds only: each click shows the next toast kind (success →
/// warning → error → …), so the kinds and their stacking can be tried
/// without making something fail. Release builds get nothing (the strings
/// are developer text, not localised, for that reason).
class DebugToastButton extends StatefulWidget {
  const DebugToastButton({super.key});

  @override
  State<DebugToastButton> createState() => _DebugToastButtonState();
}

class _DebugToastButtonState extends State<DebugToastButton> {
  static const _samples = {
    AppToastKind.success: 'Debug: message copied',
    AppToastKind.warning:
        'Debug: a reaction can only be taken back within '
        '2 minutes',
    AppToastKind.error:
        "Debug: couldn't send the file — the connection "
        'dropped',
  };

  int _next = 0;

  void _show() {
    final kind = AppToastKind.values[_next % AppToastKind.values.length];
    _next++;
    showAppSnack(context, _samples[kind] ?? kind.name, kind: kind);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final s = context.spacing;
    return Tooltip(
      message: 'Debug: test toasts (success → warning → error)',
      child: HoverSurface(
        onTap: _show,
        width: s.xl5 + s.xs,
        height: s.xl5 + s.xs,
        alignment: Alignment.center,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Icon(
          LucideIcons.bellRing300,
          size: s.xl3,
          color: context.colors.warning,
        ),
      ),
    );
  }
}
