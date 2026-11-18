import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';

/// What a video frame shows under its controls: the [player] while it plays
/// there, else the video's preview image — of the picked bytes while it is
/// still an upload ([uploadGid]) — on black until one is ready, as a player
/// would be.
class ChatVideoPicture extends ConsumerWidget {
  const ChatVideoPicture({
    super.key,
    required this.accountId,
    required this.file,
    this.uploadGid,
    this.player,
  });

  final String accountId;
  final FileContent file;
  final String? uploadGid;
  final VideoPlayerController? player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gid = uploadGid;
    final player = this.player;
    // Watched while it plays too, so the image is still there after.
    final frame = switch (ref.watch(
      gid == null
          ? chatVideoThumbnailProvider((accountId: accountId, video: file))
          : chatPendingVideoThumbnailProvider((gid: gid, name: file.name)),
    )) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: context.colors.scrim),
        if (player != null)
          Center(
            child: AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
          )
        else if (frame != null)
          Image.memory(frame, fit: BoxFit.cover),
      ],
    );
  }
}
