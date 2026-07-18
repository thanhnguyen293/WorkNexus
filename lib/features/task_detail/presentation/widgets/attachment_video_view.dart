import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
    if (_failed) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.xl4),
        child: Center(
          child: Text(
            AppL10n.of(context).attachmentLoadFailed,
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.xl4),
        child: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }
    final playing = _controller.value.isPlaying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: GestureDetector(
            onTap: _toggle,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                if (!playing)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: c.scrim.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow, color: c.onAccent, size: 34),
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
              _ControlButton(
                icon: playing ? Icons.pause : Icons.play_arrow,
                onTap: _toggle,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                // Rounded, taller track so the buffered (loaded) span reads
                // clearly: faint track → light "buffered" fill → accent played.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.radii.pill),
                  child: SizedBox(
                    height: 5,
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      padding: EdgeInsets.zero,
                      colors: VideoProgressColors(
                        playedColor: c.accent,
                        bufferedColor: c.mixT(c.textPrimary, 0.45),
                        backgroundColor: c.mixT(c.textPrimary, 0.14),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.spacing.md),
              Text(
                '${_fmt(_controller.value.position)} / '
                '${_fmt(_controller.value.duration)}',
                style: context.typography.monoXs.copyWith(
                  color: c.textSecondary,
                ),
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

/// A small circular play/pause control tinted to the app surface.
class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 20, color: c.textPrimary),
      ),
    );
  }
}
