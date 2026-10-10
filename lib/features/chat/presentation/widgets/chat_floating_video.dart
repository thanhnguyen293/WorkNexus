import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_video_playback.dart';
import 'chat_video_tile_parts.dart';

/// Width of the floating mini player (a portrait video's is narrower).
const double _kMiniWidth = 240;

/// The playing video of [thread], floating over the message list while its
/// message is scrolled out of view: top-left at first, dragged anywhere in
/// the list, a click pauses / resumes and × stops it. Leaving the chat stops
/// it too.
class ChatFloatingVideo extends ConsumerStatefulWidget {
  const ChatFloatingVideo({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  ConsumerState<ChatFloatingVideo> createState() => _ChatFloatingVideoState();
}

class _ChatFloatingVideoState extends ConsumerState<ChatFloatingVideo> {
  /// Top-left corner of the mini player in the list; null = the default
  /// spot (just inside the top-left corner).
  Offset? _at;
  late final ChatVideoPlaybackNotifier _playback;

  @override
  void initState() {
    super.initState();
    // Kept for dispose, where `ref` can no longer be read.
    _playback = ref.read(chatVideoPlaybackProvider.notifier);
  }

  @override
  void dispose() {
    // The chat is closed: its video does not play on unseen. After this
    // frame — providers can't change while the tree is torn down.
    final playback = _playback;
    final thread = widget.thread;
    Future.microtask(() => playback.stopIn(thread));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(chatVideoPlaybackProvider);
    if (playback == null || !playback.floating) return const SizedBox.shrink();
    if (playback.thread != widget.thread) {
      // Floating from another chat (switched away while it played): stop.
      WidgetsBinding.instance.addPostFrameCallback((_) => _playback.stop());
      return const SizedBox.shrink();
    }
    final s = context.spacing;
    final player = playback.player;
    // Portrait to landscape, never a sliver or a banner.
    final aspect = player.value.aspectRatio.clamp(9 / 16, 16 / 9);
    final size = aspect < 1
        ? Size(_kMiniWidth * 0.6, _kMiniWidth * 0.6 / aspect)
        : Size(_kMiniWidth, _kMiniWidth / aspect);
    return LayoutBuilder(
      builder: (context, box) {
        Offset clamp(Offset o) => Offset(
          o.dx.clamp(0, (box.maxWidth - size.width).clamp(0, double.infinity)),
          o.dy.clamp(
            0,
            (box.maxHeight - size.height).clamp(0, double.infinity),
          ),
        );
        final at = clamp(_at ?? Offset(s.md, s.md));
        return Stack(
          children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              width: size.width,
              height: size.height,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _at = clamp(at + d.delta)),
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: _MiniPlayer(player: player, onClose: _playback.stop),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The mini player itself: the video with a soft shadow, play while paused,
/// × top-right and a thin progress line along the bottom.
class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.player, required this.onClose});

  final VideoPlayerController player;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.35),
            blurRadius: s.xl4,
            offset: Offset(0, s.sm),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.scrim),
            Center(
              child: AspectRatio(
                aspectRatio: player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  player.value.isPlaying ? player.pause() : player.play(),
            ),
            IgnorePointer(
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: player,
                  builder: (context, v, _) => v.isPlaying
                      ? const SizedBox.shrink()
                      : ChatVideoDisc(
                          child: Padding(
                            padding: EdgeInsets.only(left: s.xxs),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: s.xl4,
                              color: c.onScrim,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: s.sm,
              right: s.sm,
              child: ChatVideoCornerButton(
                icon: LucideIcons.x300,
                tooltip: AppL10n.of(context).close,
                onPressed: onClose,
              ),
            ),
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
  }
}
