import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// In-app video playback for a cached attachment file, with a tap-to-toggle
/// play/pause overlay and a scrub bar. Owns its [VideoPlayerController].
class AttachmentVideoView extends StatefulWidget {
  const AttachmentVideoView({super.key, required this.path});

  final String path;

  @override
  State<AttachmentVideoView> createState() => _AttachmentVideoViewState();
}

class _AttachmentVideoViewState extends State<AttachmentVideoView> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _ready = true);
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() => _failed = true);
          });
    _controller.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    if (_failed) {
      return AppStateView.error(title: l.attachmentLoadFailed);
    }
    if (!_ready) return const AppStateView.loading();
    final playing = _controller.value.isPlaying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          // Clicking the picture toggles playback; the play button below is
          // the keyboard-reachable control, so this surface stays unfocusable.
          child: HoverSurface(
            onTap: _toggle,
            focusable: false,
            tintOnHover: false,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                if (!playing)
                  Container(
                    width: context.sizes.stateTile,
                    height: context.sizes.stateTile,
                    decoration: BoxDecoration(
                      color: c.scrim.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.play300,
                      color: c.onAccent,
                      size: context.sizes.iconXl,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacing.lg,
            context.spacing.sm,
            context.spacing.lg,
            context.spacing.lg,
          ),
          child: Row(
            children: [
              AppIconButton(
                icon: playing ? LucideIcons.pause300 : LucideIcons.play300,
                tooltip: playing ? l.taskDetailPause : l.taskDetailPlay,
                onPressed: _toggle,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(child: _SeekBar(controller: _controller)),
              SizedBox(width: context.spacing.md),
              Text(
                '${_fmt(_controller.value.position)} / '
                '${_fmt(_controller.value.duration)}',
                style: context.typography.mono.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// A thin progress track that seeks on tap or drag anywhere along its width.
/// The visible bar stays 5px, but the gesture area is a full-height row so the
/// target is easy to hit; [VideoProgressIndicator] only draws (played +
/// buffered + track), while the seek is handled here via [seekTo].
class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.controller});

  final VideoPlayerController controller;

  void _seekToFraction(double dx, double width) {
    if (width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    controller.seekTo(controller.value.duration * fraction);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = controller.value;
    final durationMs = value.duration.inMilliseconds;
    final played = durationMs == 0
        ? 0.0
        : (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
    return MouseRegion(
      // Signal the bar is seekable with a hand pointer on hover.
      cursor: SystemMouseCursors.click,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seekToFraction(d.localPosition.dx, width),
            onHorizontalDragStart: (d) =>
                _seekToFraction(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) =>
                _seekToFraction(d.localPosition.dx, width),
            // Tall, full-width hit area so the thin bar is easy to grab.
            child: SizedBox(
              height: context.sizes.controlMd,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rounded track so the buffered (loaded) span reads clearly:
                  // faint track → light "buffered" fill → accent played.
                  // Drawing only; the seek is handled by the wrapper.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.radii.pill),
                    child: SizedBox(
                      height: 5,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: false,
                        padding: EdgeInsets.zero,
                        colors: VideoProgressColors(
                          playedColor: c.accent,
                          bufferedColor: c.mixT(c.textPrimary, 0.45),
                          backgroundColor: c.mixT(c.textPrimary, 0.14),
                        ),
                      ),
                    ),
                  ),
                  // Playhead thumb — a clear "draggable" affordance.
                  Align(
                    alignment: Alignment(2 * played - 1, 0),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.onAccent, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
