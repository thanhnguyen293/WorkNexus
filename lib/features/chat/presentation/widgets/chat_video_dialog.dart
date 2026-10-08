import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/result.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_image_viewer.dart';
import 'chat_labels.dart';
import 'chat_media_strip.dart';
import 'chat_media_viewer_bar.dart';
import 'chat_media_viewer_frame.dart';
import 'chat_snack.dart';
import 'chat_video_controls.dart';

/// Player for a video sent in chat, centred over it in the image viewer's dark
/// style. The file is played from the local cache: the platform player
/// cannot trust xxd's pinned self-signed certificate. Click toggles play;
/// keys: Space, ←/→ (±10 s), ↑/↓ (volume), M (mute), F (full screen), Esc.
class ChatVideoDialog extends ConsumerStatefulWidget {
  const ChatVideoDialog({
    super.key,
    required this.accountId,
    required this.video,
    this.chatGid,
  });

  final String accountId;
  final FileContent video;

  /// The chat the video is from: its photos and videos then show in a strip
  /// along the bottom to switch to.
  final String? chatGid;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required FileContent video,
    String? chatGid,
  }) => showDialog<void>(
    context: context,
    barrierColor: context.colors.scrim.withValues(
      alpha: kChatViewerBarrierAlpha,
    ),
    builder: (_) =>
        ChatVideoDialog(accountId: accountId, video: video, chatGid: chatGid),
  );

  @override
  ConsumerState<ChatVideoDialog> createState() => _ChatVideoDialogState();
}

class _ChatVideoDialogState extends ConsumerState<ChatVideoDialog> {
  final _window = const DesktopWindowService();
  VideoPlayerController? _player;
  String? _path;
  String? _error;

  /// The window went full screen for the video: the viewer fills it.
  bool _fullScreen = false;

  Future<void> _toggleFullScreen() async {
    setState(() => _fullScreen = !_fullScreen);
    await _window.toggleFullScreen();
  }

  /// A strip pick: the photo or video opens in this viewer's place.
  void _pick(MessageContent media) {
    if (indexOfChatMedia([widget.video], media) >= 0) return;
    final navigator = Navigator.of(context)..pop();
    switch (media) {
      case final ImageContent image:
        ChatImageViewer.show(
          navigator.context,
          accountId: widget.accountId,
          images: [image],
          initialIndex: 0,
          chatGid: widget.chatGid,
        );
      case final FileContent video:
        ChatVideoDialog.show(
          navigator.context,
          accountId: widget.accountId,
          video: video,
          chatGid: widget.chatGid,
        );
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await ref
        .read(chatControllerProvider)
        .attachmentFile(widget.accountId, widget.video);
    if (!mounted) return;
    switch (path) {
      case Ok(:final value):
        final player = VideoPlayerController.file(File(value));
        try {
          await player.initialize();
        } on Exception {
          await player.dispose();
          if (mounted) {
            setState(() => _error = AppL10n.of(context).chatVideoFailed);
          }
          return;
        }
        if (!mounted) {
          await player.dispose();
          return;
        }
        setState(() {
          _player = player;
          _path = value;
        });
        await player.play();
      case Err(:final failure):
        setState(() => _error = failure.message);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    // Leaving the player leaves full screen too.
    _window.exitFullScreen();
    super.dispose();
  }

  void _togglePlay() {
    final p = _player;
    if (p == null) return;
    p.value.isPlaying ? p.pause() : p.play();
  }

  void _seek(Duration delta) {
    final p = _player;
    if (p != null) p.seekTo(p.value.position + delta);
  }

  void _volume(double delta) {
    final p = _player;
    if (p != null) p.setVolume((p.value.volume + delta).clamp(0, 1));
  }

  Future<void> _save() async {
    final path = _path;
    if (path == null) return;
    final saved = AppL10n.of(context).chatSaved;
    if (await saveAttachmentAs(path, widget.video.name) && mounted) {
      showChatSnack(context, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final player = _player;
    final path = _path;
    final size = player?.value.size;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seek(-kChatVideoSeekStep),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seek(kChatVideoSeekStep),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _volume(0.1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _volume(-0.1),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            player?.setVolume(player.value.volume == 0 ? 1 : 0),
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullScreen,
      },
      child: Focus(
        autofocus: true,
        child: ChatMediaViewerFrame(
          expanded: _fullScreen,
          child: Column(
            children: [
              ChatMediaViewerBar(
                title: widget.video.name,
                details: [
                  if (widget.video.size > 0) formatFileSize(widget.video.size),
                  if (size != null && size.width > 0)
                    '${size.width.round()}×${size.height.round()}',
                  if (player != null) formatVideoTime(player.value.duration),
                ],
                onClose: () => Navigator.of(context).pop(),
                actions: [
                  ChatViewerButton(
                    icon: PhosphorIconsLight.downloadSimple,
                    tooltip: l.chatSaveAs,
                    onPressed: path == null ? null : _save,
                  ),
                  ChatViewerButton(
                    icon: PhosphorIconsLight.arrowSquareOut,
                    tooltip: l.chatOpenWith,
                    onPressed: path == null ? null : () => openExternally(path),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.xl3),
                  child: Center(
                    child: switch ((player, _error)) {
                      (_, final String error) => Text(
                        error,
                        style: context.typography.body.copyWith(
                          color: c.onScrim,
                        ),
                      ),
                      (null, _) => CircularProgressIndicator(color: c.onScrim),
                      (final VideoPlayerController p, _) => GestureDetector(
                        onTap: _togglePlay,
                        onDoubleTap: _toggleFullScreen,
                        child: AspectRatio(
                          aspectRatio: p.value.aspectRatio,
                          child: VideoPlayer(p),
                        ),
                      ),
                    },
                  ),
                ),
              ),
              if (player != null)
                ChatVideoControls(
                  player: player,
                  onToggleFullScreen: _toggleFullScreen,
                ),
              if (widget.chatGid case final gid?)
                ChatMediaStrip(
                  thread: (accountId: widget.accountId, chatGid: gid),
                  current: widget.video,
                  onPick: _pick,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
