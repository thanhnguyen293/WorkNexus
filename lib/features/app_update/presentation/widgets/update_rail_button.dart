import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/update_controller.dart';
import '../providers/update_state.dart';

/// The rail's "restart to update" button, in the utilities group above
/// Integrations: hidden until the background check finds a newer release;
/// while it downloads, a ring round the icon fills with the progress (and
/// spins while installing); once verified, restarts into it on tap. Watching the
/// controller here also starts the hourly check with the app. A release
/// without an in-app build opens its release page.
class UpdateRailButton extends ConsumerWidget {
  const UpdateRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final l = AppL10n.of(context);
    return switch (state) {
      UpdateDownloading(:final progress) => AppRailButton(
        leading: _ProgressIcon(progress: progress),
        label: l.updateDownloadingPercent((progress * 100).round()),
        selected: false,
        // Nothing to do until it is downloaded; the tooltip says how far.
        onTap: () {},
      ),
      UpdateInstalling(:final update) => AppRailButton(
        leading: const _ProgressIcon(),
        label: l.updateRestartToUpdate(update.latestVersion),
        selected: false,
        onTap: () {},
      ),
      UpdateReady(:final update) => AppRailButton(
        icon: LucideIcons.circleFadingArrowUp300,
        label: l.updateRestartToUpdate(update.latestVersion),
        selected: false,
        onTap: () =>
            ref.read(updateControllerProvider.notifier).installAndRestart(),
        badge: const _AttentionDot(),
      ),
      UpdateManual(:final update) ||
      UpdateFailed(:final update) => AppRailButton(
        icon: LucideIcons.circleFadingArrowUp300,
        label: l.updateAvailable(update.latestVersion),
        selected: false,
        onTap: () => openExternally(update.releaseUrl),
        badge: const _AttentionDot(),
      ),
      UpdateIdle() => const SizedBox.shrink(),
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

/// The update arrow inside a ring that fills with [progress] (0..1), or
/// spins when it is null (installing).
class _ProgressIcon extends StatelessWidget {
  const _ProgressIcon({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = context.sizes.iconXl;
    return SizedBox.square(
      dimension: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: side,
            child: TweenAnimationBuilder<double>(
              // Eases between the controller's 1 % steps.
              tween: Tween(end: progress ?? 0),
              duration: AppMotion.base,
              builder: (context, value, _) => CircularProgressIndicator(
                value: progress == null ? null : value,
                strokeWidth: context.spacing.xxs,
                color: c.accent,
                backgroundColor: c.border,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Icon(
            LucideIcons.arrowUp300,
            size: context.sizes.iconSm,
            color: c.accent,
          ),
        ],
      ),
    );
  }
}
