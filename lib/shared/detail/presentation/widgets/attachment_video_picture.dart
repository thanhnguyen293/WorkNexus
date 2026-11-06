import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/load_speed_meter.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// The video picture: a click plays / pauses it, a play disc shows while it
/// is paused, and a spinner with how much has loaded while it waits for data.
class AttachmentVideoPicture extends StatelessWidget {
  const AttachmentVideoPicture({
    super.key,
    required this.player,
    required this.onTap,
    this.sizeBytes,
  });

  final VideoPlayerController player;
  final VoidCallback onTap;

  /// The file's size, to tell how fast it loads; null shows no speed.
  final int? sizeBytes;

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
              _LoadingBadge(player: player, sizeBytes: sizeBytes)
            else if (!v.isPlaying)
              const _PlayDisc(),
          ],
        ),
      ),
    );
  }
}

/// How much of the video has loaded, 0–1: the end of its furthest buffer.
double _loadedFraction(VideoPlayerValue v) {
  final total = v.duration.inMilliseconds;
  if (total <= 0) return 0;
  var end = 0;
  for (final r in v.buffered) {
    if (r.end.inMilliseconds > end) end = r.end.inMilliseconds;
  }
  return (end / total).clamp(0.0, 1.0);
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

/// A spinner and "Loading 32% · 1.2 MB/s" while the player waits for data.
/// The speed is the growth of the loaded share of the file, sampled twice a
/// second.
class _LoadingBadge extends StatefulWidget {
  const _LoadingBadge({required this.player, required this.sizeBytes});

  final VideoPlayerController player;
  final int? sizeBytes;

  @override
  State<_LoadingBadge> createState() => _LoadingBadgeState();
}

class _LoadingBadgeState extends State<_LoadingBadge> {
  final _meter = LoadSpeedMeter();
  late final Timer _sampler;

  @override
  void initState() {
    super.initState();
    _sample();
    _sampler = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(_sample),
    );
  }

  void _sample() {
    final size = widget.sizeBytes;
    if (size == null || size <= 0) return;
    final loaded = (_loadedFraction(widget.player.value) * size).round();
    _meter.add(DateTime.now(), loaded);
  }

  @override
  void dispose() {
    _sampler.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final percent = (_loadedFraction(widget.player.value) * 100).round();
    final speed = _meter.bytesPerSecond;
    final label = speed == null
        ? l.videoBuffering(percent)
        : l.videoBufferingSpeed(percent, formatFileSize(speed.round()) ?? '');
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
            label,
            style: context.typography.captionStrong.copyWith(color: c.onScrim),
          ),
        ],
      ),
    );
  }
}
