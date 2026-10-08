import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';

/// Plays a video sent in chat. The file is downloaded through the chat
/// connection first: the platform player cannot trust xxd's pinned
/// self-signed certificate, so it plays from a local file.
class ChatVideoDialog extends ConsumerStatefulWidget {
  const ChatVideoDialog({
    super.key,
    required this.accountId,
    required this.video,
  });

  final String accountId;
  final FileContent video;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required FileContent video,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ChatVideoDialog(accountId: accountId, video: video),
  );

  @override
  ConsumerState<ChatVideoDialog> createState() => _ChatVideoDialogState();
}

class _ChatVideoDialogState extends ConsumerState<ChatVideoDialog> {
  VideoPlayerController? _player;
  String? _error;

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
        setState(() => _player = player);
        await player.play();
      case Err(:final failure):
        setState(() => _error = failure.message);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final player = _player;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.video.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.title.copyWith(color: c.textPrimary),
              ),
              SizedBox(height: context.spacing.lg),
              if (_error != null)
                AppInlineNote(text: _error!, isError: true)
              else if (player == null)
                Column(
                  children: [
                    const AppInlineSpinner(),
                    Text(
                      l.chatDownloading,
                      style: context.typography.caption.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                )
              else ...[
                Flexible(
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                ),
                VideoProgressIndicator(player, allowScrubbing: true),
                _PlayPause(player: player),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPause extends StatelessWidget {
  const _PlayPause({required this.player});

  final VideoPlayerController player;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: player,
    builder: (context, value, _) => IconButton(
      onPressed: value.isPlaying ? player.pause : player.play,
      icon: Icon(
        value.isPlaying ? Icons.pause : Icons.play_arrow,
        color: context.colors.textPrimary,
      ),
    ),
  );
}
