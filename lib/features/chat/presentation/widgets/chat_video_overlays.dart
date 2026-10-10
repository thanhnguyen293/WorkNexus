import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'attachment_download_badge.dart';
import 'chat_video_controls.dart' show formatVideoTime;
import 'chat_video_tile_parts.dart';

/// The middle of the frame: the upload's or download's progress, a spinner
/// while the player starts, else play — hidden while it plays.
class ChatVideoCentreControl extends ConsumerWidget {
  const ChatVideoCentreControl({
    super.key,
    required this.accountId,
    required this.file,
    required this.uploadGid,
    required this.uploading,
    required this.starting,
    required this.player,
  });

  final String accountId;
  final FileContent file;
  final String? uploadGid;
  final bool uploading;
  final bool starting;
  final VideoPlayerController? player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uploadGid case final gid?) {
      return uploading
          ? ChatVideoDisc(child: ChatVideoUploadRing(messageGid: gid))
          : const SizedBox.shrink();
    }
    final key = (accountId: accountId, content: file);
    if (ref.watch(chatDownloadingProvider.select((d) => d.contains(key)))) {
      return ChatVideoDisc(
        child: ChatVideoProgressRing(
          value: ref.watch(chatDownloadProgressProvider(key)).value,
        ),
      );
    }
    if (starting) {
      return const ChatVideoDisc(child: ChatVideoProgressRing(value: null));
    }
    final p = player;
    if (p == null) return const _PlayGlyph();
    return ValueListenableBuilder(
      valueListenable: p,
      builder: (context, v, _) =>
          v.isPlaying ? const SizedBox.shrink() : const _PlayGlyph(),
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) => ChatVideoDisc(
    // Optically centred: a triangle's weight sits left of its box.
    child: Padding(
      padding: EdgeInsets.only(left: context.spacing.xxs),
      child: Icon(
        Icons.play_arrow_rounded,
        size: context.spacing.xl4,
        color: context.colors.onScrim,
      ),
    ),
  );
}

/// The length — position / length while it plays — with the download arrow
/// beside it while the video is not on this device yet.
class ChatVideoTimeCorner extends StatelessWidget {
  const ChatVideoTimeCorner({
    super.key,
    required this.accountId,
    required this.file,
    required this.player,
    required this.duration,
    required this.showDownload,
  });

  final String accountId;
  final FileContent file;
  final VideoPlayerController? player;
  final Duration? duration;
  final bool showDownload;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final known = duration;
    final Widget time = p != null
        ? ValueListenableBuilder(
            valueListenable: p,
            builder: (context, v, _) => ChatVideoPill(
              text:
                  '${formatVideoTime(v.position)} / '
                  '${formatVideoTime(v.duration)}',
            ),
          )
        : known != null
        ? ChatVideoPill(text: formatVideoTime(known))
        : const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        time,
        if (showDownload && p == null) ...[
          SizedBox(width: context.spacing.xs),
          // The size already shows at the top: just the arrow.
          AttachmentDownloadBadge(accountId: accountId, content: file, size: 0),
        ],
      ],
    );
  }
}
