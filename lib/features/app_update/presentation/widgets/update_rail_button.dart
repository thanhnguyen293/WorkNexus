import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/update_controller.dart';
import '../providers/update_state.dart';

/// The rail's "restart to update" button, above Integrations: hidden until the
/// background check has a newer release downloaded and verified, then restarts
/// into it on tap. Watching the controller here also starts the hourly check
/// with the app. A release without an in-app build opens its release page.
class UpdateRailButton extends ConsumerWidget {
  const UpdateRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final l = AppL10n.of(context);
    return switch (state) {
      UpdateReady(:final update) ||
      UpdateInstalling(:final update) => AppRailButton(
        icon: PhosphorIconsLight.arrowCircleUp,
        selectedIcon: PhosphorIconsFill.arrowCircleUp,
        label: l.updateRestartToUpdate(update.latestVersion),
        selected: false,
        onTap: () =>
            ref.read(updateControllerProvider.notifier).installAndRestart(),
        badge: const _AttentionDot(),
      ),
      UpdateManual(:final update) ||
      UpdateFailed(:final update) => AppRailButton(
        icon: PhosphorIconsLight.arrowCircleUp,
        selectedIcon: PhosphorIconsFill.arrowCircleUp,
        label: l.updateAvailable(update.latestVersion),
        selected: false,
        onTap: () => openExternally(update.releaseUrl),
        badge: const _AttentionDot(),
      ),
      UpdateIdle() || UpdateDownloading() => const SizedBox.shrink(),
    };
  }
}

/// Accent dot on the icon's corner, so the new button catches the eye.
class _AttentionDot extends StatelessWidget {
  const _AttentionDot();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: s.lg,
      height: s.lg,
      decoration: BoxDecoration(
        color: c.accent,
        shape: BoxShape.circle,
        border: Border.all(color: c.surface, width: s.xxs),
      ),
    );
  }
}
