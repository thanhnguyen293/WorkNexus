import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_video_playback.dart';
import 'attachment_download.dart';
import 'chat_snack.dart';
import 'chat_video_dialog.dart';
import 'chat_video_dock_watcher.dart';
import 'chat_video_overlays.dart';
import 'chat_video_tile_parts.dart';

/// A video as a 16:9 frame: its preview image (when one can be made), the
/// name and size along the top, the length bottom-left and a full-screen
/// button bottom-right. Play starts it right in the frame (downloading it
/// first when needed); a click then pauses / resumes, and full screen opens
/// the viewer ([onFullScreen]).
///
/// An own video not uploaded yet ([uploadGid] set) is drawn the same from the
/// picked bytes, with the upload's progress ([uploading]) where play is.
class ChatVideoTile extends ConsumerStatefulWidget {
  const ChatVideoTile({
    super.key,
    required this.accountId,
    required this.file,
    this.chatGid,
    this.messageGid,
    this.onFullScreen,
    this.uploadGid,
    this.uploading = false,
  });

  final String accountId;
  final FileContent file;

  /// The chat and message the video is in: playing in the frame needs them
  /// (null = the frame only opens the viewer).
  final String? chatGid;
  final String? messageGid;

  /// Opens the viewer while the video is not playing here.
  final VoidCallback? onFullScreen;

  /// The gid of the own message whose upload this video still is.
  final String? uploadGid;

  /// Still sending (rather than failed): shows the progress.
  final bool uploading;

  @override
  ConsumerState<ChatVideoTile> createState() => _ChatVideoTileState();
}

class _ChatVideoTileState extends ConsumerState<ChatVideoTile> {
  bool _starting = false;
  late final ChatVideoPlaybackNotifier _playback;

  @override
  void initState() {
    super.initState();
    // Kept for dispose, where `ref` can no longer be read.
    _playback = ref.read(chatVideoPlaybackProvider.notifier);
  }

  /// The shared player when it plays this message's video.
  ChatVideoPlayback? get _mine => switch (ref.read(chatVideoPlaybackProvider)) {
    final p? when p.messageGid == widget.messageGid => p,
    _ => null,
  };

  /// Plays in the frame: downloads first when needed, then starts; once
  /// playing, a click pauses / resumes.
  Future<void> _play() async {
    final player = _mine?.player;
    if (player != null) {
      player.value.isPlaying ? await player.pause() : await player.play();
      return;
    }
    if (_starting || widget.messageGid == null || widget.chatGid == null) {
      return;
    }
    setState(() => _starting = true);
    await openAttachment(
      context,
      ref,
      accountId: widget.accountId,
      content: widget.file,
      open: _start,
    );
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _start() async {
    final (gid, chatGid) = (widget.messageGid, widget.chatGid);
    if (gid == null || chatGid == null) return;
    final path = await ref
        .read(chatControllerProvider)
        .attachmentFile(widget.accountId, widget.file);
    if (!mounted) return;
    switch (path) {
      case Ok(:final value):
        final ok = await _playback.start(
          thread: (accountId: widget.accountId, chatGid: chatGid),
          messageGid: gid,
          file: widget.file,
          path: value,
        );
        if (!ok && mounted) {
          showChatSnack(context, AppL10n.of(context).chatVideoFailed);
        }
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  /// The viewer takes over from where the frame is, and hands the spot back
  /// when it closes (paused, as the viewer leaves it).
  Future<void> _fullScreen() async {
    final player = _mine?.player;
    if (player == null) {
      widget.onFullScreen?.call();
      return;
    }
    await player.pause();
    if (!mounted) return;
    await ChatVideoDialog.show(
      context,
      accountId: widget.accountId,
      video: widget.file,
      chatGid: widget.chatGid,
      startAt: player.value.position,
      onClosed: (at) {
        if (at != null && _mine?.player == player) player.seekTo(at);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final gid = widget.uploadGid;
    // Played here only while docked: floating, the mini player shows it.
    final playback = ref.watch(chatVideoPlaybackProvider);
    final player =
        playback != null &&
            playback.messageGid == widget.messageGid &&
            !playback.floating
        ? playback.player
        : null;
    final frame = switch (ref.watch(
      gid == null
          ? chatVideoThumbnailProvider((
              accountId: widget.accountId,
              video: widget.file,
            ))
          : chatPendingVideoThumbnailProvider((
              gid: gid,
              name: widget.file.name,
            )),
    )) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    // Nothing on the server to measure or download yet.
    final duration = gid != null
        ? null
        : switch (ref.watch(
            chatVideoDurationProvider((
              accountId: widget.accountId,
              video: widget.file,
            )),
          )) {
            AsyncData(value: Ok(:final value)) => value,
            _ => null,
          };

    final clip = ClipRRect(
      borderRadius: BorderRadius.circular(context.radii.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Black until a frame is ready, as a player would be.
            ColoredBox(color: c.scrim),
            if (player != null)
              Center(
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              )
            else if (frame != null)
              Image.memory(frame, fit: BoxFit.cover),
            // The whole frame plays / pauses (a sent video only).
            if (gid == null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: _play,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: ChatVideoNameBar(
                  name: widget.file.name,
                  size: widget.file.size,
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: ChatVideoCentreControl(
                  accountId: widget.accountId,
                  file: widget.file,
                  uploadGid: gid,
                  uploading: widget.uploading,
                  starting: _starting,
                  player: player,
                ),
              ),
            ),
            Positioned(
              left: s.md,
              bottom: s.md,
              child: IgnorePointer(
                child: ChatVideoTimeCorner(
                  accountId: widget.accountId,
                  file: widget.file,
                  player: player,
                  duration: duration,
                  showDownload: gid == null,
                ),
              ),
            ),
            if (gid == null && widget.onFullScreen != null)
              Positioned(
                right: s.md,
                bottom: s.md,
                child: ChatVideoCornerButton(
                  icon: LucideIcons.maximize300,
                  tooltip: AppL10n.of(context).chatFullScreen,
                  onPressed: _fullScreen,
                ),
              ),
            if (player != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ChatVideoProgressLine(player: player),
              ),
          ],
        ),
      ),
    );
    final messageGid = widget.messageGid;
    return messageGid == null
        ? clip
        : ChatVideoDockWatcher(messageGid: messageGid, child: clip);
  }
}
