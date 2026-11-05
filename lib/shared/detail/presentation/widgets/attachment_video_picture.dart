import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// The video picture: a click plays / pauses it, a play disc shows while it
/// is paused, and a spinner with how much has loaded while it waits for data.
class AttachmentVideoPicture extends StatelessWidget {
  const AttachmentVideoPicture({
    super.key,
    required this.player,
    required this.onTap,
  });

  final VideoPlayerController player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The play button in the controls is the keyboard-reachable one, so this
    // surface stays unfocusable.
    return HoverSurface(
      onTap: onTap,
      focusable: false,
      tintOnHover: false,
      child: ValueListenableBuilder(
        valueListenable: player,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(player)),
            if (v.isBuffering)
              _LoadingBadge(percent: _loadedPercent(v))
            else if (!v.isPlaying)
              const _PlayDisc(),
          ],
        ),
      ),
    );
  }

  static int _loadedPercent(VideoPlayerValue v) {
    final total = v.duration.inMilliseconds;
    if (total <= 0) return 0;
    var end = 0;
    for (final r in v.buffered) {
      if (r.end.inMilliseconds > end) end = r.end.inMilliseconds;
    }
    return (end * 100 / total).round().clamp(0, 100);
  }
}

class _PlayDisc extends StatelessWidget {
  const _PlayDisc();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: context.sizes.stateTile,
      height: context.sizes.stateTile,
      decoration: BoxDecoration(
        color: c.scrim.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      // Optically centred: a triangle's weight sits left of its box.
      padding: EdgeInsets.only(left: context.spacing.xxs),
      child: Icon(
        LucideIcons.play300,
        color: c.onScrim,
        size: context.sizes.iconXl,
      ),
    );
  }
}

/// A spinner and "Loading 32%" while the player waits for data.
class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
      decoration: BoxDecoration(
        color: c.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: context.sizes.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: s.xxs,
              color: c.onScrim,
            ),
          ),
          SizedBox(width: s.md),
          Text(
            AppL10n.of(context).videoBuffering(percent),
            style: context.typography.captionStrong.copyWith(color: c.onScrim),
          ),
        ],
      ),
    );
  }
}
