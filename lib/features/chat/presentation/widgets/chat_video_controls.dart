import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_media_viewer_bar.dart';

/// Playback speeds offered by the speed menu.
const _kSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Seek step of the ±10 s buttons (and the arrow keys).
const kChatVideoSeekStep = Duration(seconds: 10);

/// The video viewer's bottom controls: a seek bar with times, play/pause,
/// ±10 s, volume/mute, speed, loop and full screen.
class ChatVideoControls extends StatelessWidget {
  const ChatVideoControls({
    super.key,
    required this.player,
    required this.onToggleFullScreen,
  });

  final VideoPlayerController player;
  final VoidCallback onToggleFullScreen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final ink = c.onScrim;
    final time = context.typography.captionStrong.copyWith(color: ink);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.scrim.withValues(alpha: 0.6)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.sm),
        child: ValueListenableBuilder(
          valueListenable: player,
          builder: (context, v, _) {
            final total = v.duration.inMilliseconds;
            final at = v.position.inMilliseconds.clamp(0, total);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(formatVideoTime(v.position), style: time),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: c.accent,
                          inactiveTrackColor: ink.withValues(alpha: 0.25),
                          thumbColor: ink,
                          overlayColor: ink.withValues(alpha: 0.12),
                          trackHeight: s.xs,
                        ),
                        child: Slider(
                          max: total <= 0 ? 1 : total.toDouble(),
                          value: total <= 0 ? 0 : at.toDouble(),
                          onChanged: total <= 0
                              ? null
                              : (ms) => player.seekTo(
                                  Duration(milliseconds: ms.round()),
                                ),
                        ),
                      ),
                    ),
                    Text(formatVideoTime(v.duration), style: time),
                  ],
                ),
                Row(
                  children: [
                    ChatViewerButton(
                      icon: LucideIcons.rotateCcw300,
                      tooltip: l.chatBack10,
                      onPressed: () =>
                          player.seekTo(v.position - kChatVideoSeekStep),
                    ),
                    ChatViewerButton(
                      icon: v.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      tooltip: v.isPlaying ? l.chatPause : l.chatPlay,
                      onPressed: v.isPlaying ? player.pause : player.play,
                    ),
                    ChatViewerButton(
                      icon: LucideIcons.rotateCw300,
                      tooltip: l.chatForward10,
                      onPressed: () =>
                          player.seekTo(v.position + kChatVideoSeekStep),
                    ),
                    SizedBox(width: s.md),
                    ChatViewerButton(
                      icon: v.volume == 0
                          ? LucideIcons.volumeX300
                          : LucideIcons.volume2300,
                      tooltip: v.volume == 0 ? l.chatUnmute : l.chatMute,
                      onPressed: () => player.setVolume(v.volume == 0 ? 1 : 0),
                    ),
                    SizedBox(
                      width: s.xl6 * 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: ink,
                          inactiveTrackColor: ink.withValues(alpha: 0.25),
                          thumbColor: ink,
                          trackHeight: s.xxs,
                        ),
                        child: Slider(
                          value: v.volume,
                          onChanged: player.setVolume,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<double>(
                      tooltip: l.chatSpeed,
                      initialValue: v.playbackSpeed,
                      onSelected: player.setPlaybackSpeed,
                      itemBuilder: (_) => [
                        for (final speed in _kSpeeds)
                          CheckedPopupMenuItem(
                            value: speed,
                            checked: speed == v.playbackSpeed,
                            child: Text('${speed}x'),
                          ),
                      ],
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: s.md),
                        child: Text('${v.playbackSpeed}x', style: time),
                      ),
                    ),
                    ChatViewerButton(
                      icon: LucideIcons.repeat300,
                      tooltip: l.chatLoop,
                      selected: v.isLooping,
                      onPressed: () => player.setLooping(!v.isLooping),
                    ),
                    ChatViewerButton(
                      icon: LucideIcons.maximize300,
                      tooltip: l.chatFullScreen,
                      onPressed: onToggleFullScreen,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "m:ss", or "h:mm:ss" for long videos.
String formatVideoTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}
