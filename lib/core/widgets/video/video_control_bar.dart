import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_icon_button.dart';
import 'video_time.dart';

/// Playback speeds offered by the speed menu.
const kVideoSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Seek step of the ±10 s buttons (and the arrow keys).
const kVideoSeekStep = Duration(seconds: 10);

/// The row under a video: play/pause, ±10 s, volume, the time, then speed,
/// loop and expand. [position] is the smooth one the seek bar draws.
class VideoControlBar extends StatelessWidget {
  const VideoControlBar({
    super.key,
    required this.player,
    required this.position,
    required this.expanded,
    required this.onToggleExpand,
  });

  final VideoPlayerController player;
  final Duration position;
  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final v = player.value;
    final muted = v.volume == 0;
    return Row(
      children: [
        AppIconButton(
          icon: v.isPlaying ? LucideIcons.pause300 : LucideIcons.play300,
          tooltip: v.isPlaying ? l.videoPause : l.videoPlay,
          onPressed: v.isPlaying ? player.pause : player.play,
        ),
        AppIconButton(
          icon: LucideIcons.rotateCcw300,
          tooltip: l.videoBack10,
          onPressed: () => player.seekTo(v.position - kVideoSeekStep),
        ),
        AppIconButton(
          icon: LucideIcons.rotateCw300,
          tooltip: l.videoForward10,
          onPressed: () => player.seekTo(v.position + kVideoSeekStep),
        ),
        SizedBox(width: s.sm),
        AppIconButton(
          icon: muted ? LucideIcons.volumeX300 : LucideIcons.volume2300,
          tooltip: muted ? l.videoUnmute : l.videoMute,
          onPressed: () => player.setVolume(muted ? 1 : 0),
        ),
        SizedBox(
          width: s.xl6 * 2,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: s.xxs,
              activeTrackColor: c.textSecondary,
              inactiveTrackColor: c.mixT(c.textPrimary, 0.14),
              thumbColor: c.textPrimary,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(value: v.volume, onChanged: player.setVolume),
          ),
        ),
        SizedBox(width: s.md),
        Text(
          '${formatVideoTime(position)} / ${formatVideoTime(v.duration)}',
          style: context.typography.mono.copyWith(color: c.textSecondary),
        ),
        const Spacer(),
        _SpeedMenu(player: player),
        AppIconButton(
          icon: LucideIcons.repeat300,
          tooltip: l.videoLoop,
          selected: v.isLooping,
          onPressed: () => player.setLooping(!v.isLooping),
        ),
        AppIconButton(
          icon: expanded ? LucideIcons.minimize300 : LucideIcons.maximize300,
          tooltip: expanded ? l.videoCollapse : l.videoExpand,
          onPressed: onToggleExpand,
        ),
      ],
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.player});

  final VideoPlayerController player;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final speed = player.value.playbackSpeed;
    return PopupMenuButton<double>(
      tooltip: AppL10n.of(context).videoSpeed,
      initialValue: speed,
      onSelected: player.setPlaybackSpeed,
      itemBuilder: (_) => [
        for (final option in kVideoSpeeds)
          CheckedPopupMenuItem(
            value: option,
            checked: option == speed,
            child: Text('${option}x'),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        child: Text(
          '${speed}x',
          style: context.typography.captionStrong.copyWith(
            color: speed == 1 ? c.textSecondary : c.accent,
          ),
        ),
      ),
    );
  }
}
