import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/hover_surface.dart';

/// Debug builds only: sets off the "bug resolved" fireworks on demand, so the
/// show can be tried without resolving a real bug. Release builds get
/// nothing (the tooltip is a developer string, not localised, for that
/// reason).
class DebugCelebrateButton extends ConsumerWidget {
  const DebugCelebrateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final s = context.spacing;
    return Tooltip(
      message: 'Debug: test fireworks',
      child: HoverSurface(
        onTap: () => ref.read(celebrationProvider.notifier).celebrate(),
        width: s.xl5 + s.xs,
        height: s.xl5 + s.xs,
        alignment: Alignment.center,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Icon(
          PhosphorIconsLight.confetti,
          size: s.xl3,
          color: context.colors.warning,
        ),
      ),
    );
  }
}
