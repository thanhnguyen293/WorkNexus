import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/domain/value_objects/media_request.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/video/smooth_video_position.dart';
import '../../../../core/widgets/video/video_control_bar.dart';
import '../../../../core/widgets/video/video_seek_bar.dart';
import '../../../../l10n/app_localizations.dart';
import 'attachment_video_picture.dart';

/// In-app video playback for an attachment: the picture (click to play /
/// pause, a loading badge while it buffers), a smooth seek bar and the full
/// control row, with keyboard shortcuts. Streams it when [stream] gives a
/// source (it plays while the rest downloads), else — or when that fails —
/// plays the file [download] fetches whole. Owns its [VideoPlayerController].
class AttachmentVideoView extends StatefulWidget {
  const AttachmentVideoView({
    super.key,
    required this.stream,
    required this.download,
    required this.expanded,
    required this.onToggleExpand,
  });

  final Future<MediaRequest?> Function() stream;
  final Future<String?> Function() download;

  /// Whether the viewer fills the window; [onToggleExpand] flips it.
  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  State<AttachmentVideoView> createState() => _AttachmentVideoViewState();
}

class _AttachmentVideoViewState extends State<AttachmentVideoView> {
  VideoPlayerController? _player;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final stream = await widget.stream();
    if (stream != null &&
        await _use(
          VideoPlayerController.networkUrl(
            stream.uri,
            httpHeaders: stream.headers,
          ),
        )) {
      return;
    }
    // No stream, or it didn't start (an expired session, a format the proxy
    // can't serve): fetch the whole file as before.
    final path = mounted ? await widget.download() : null;
    if (path != null && await _use(VideoPlayerController.file(File(path)))) {
      return;
    }
    if (mounted) setState(() => _failed = true);
  }

  /// Starts [player]; keeps it, playing, if it is ready and this view still
  /// shows.
  Future<bool> _use(VideoPlayerController player) async {
    try {
      await player.initialize().timeout(const Duration(seconds: 20));
    } on Exception {
      await player.dispose();
      return false;
    }
    if (!mounted) {
      await player.dispose();
      return false;
    }
    setState(() => _player = player);
    await player.play();
    return true;
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _toggle() {
    final player = _player;
    if (player == null) return;
    player.value.isPlaying ? player.pause() : player.play();
  }

  void _seek(Duration by) {
    final player = _player;
    if (player != null) player.seekTo(player.value.position + by);
  }

  void _mute() {
    final player = _player;
    if (player != null) player.setVolume(player.value.volume == 0 ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    if (_failed) return AppStateView.error(title: l.attachmentLoadFailed);
    final player = _player;
    if (player == null) return const AppStateView.loading();
    final s = context.spacing;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _toggle,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seek(-kVideoSeekStep),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seek(kVideoSeekStep),
        const SingleActivator(LogicalKeyboardKey.keyM): _mute,
        const SingleActivator(LogicalKeyboardKey.keyF): widget.onToggleExpand,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AttachmentVideoPicture(player: player, onTap: _toggle),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(s.lg, s.xs, s.lg, s.md),
              // Rebuilt each frame while playing, so only the controls are.
              child: SmoothVideoPosition(
                player: player,
                builder: (context, position) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoSeekBar(player: player, position: position),
                    VideoControlBar(
                      player: player,
                      position: position,
                      expanded: widget.expanded,
                      onToggleExpand: widget.onToggleExpand,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
