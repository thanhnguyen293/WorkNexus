import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';

/// Diameter of the round control in the middle of a chat video's frame.
const double kChatVideoDisc = 44;

/// The video's name and size across the top of its frame, on a shade that
/// fades down so they read over any picture.
class ChatVideoNameBar extends StatelessWidget {
  const ChatVideoNameBar({super.key, required this.name, required this.size});

  final String name;
  final int size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.scrim.withValues(alpha: 0.6),
            c.scrim.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.md, s.md, s.md, s.xl3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.captionStrong.copyWith(
                  color: c.onScrim,
                ),
              ),
            ),
            SizedBox(width: s.md),
            Text(
              formatFileSize(size),
              style: context.typography.caption.copyWith(
                color: c.onScrim.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round control in the middle of the frame: a soft dark disc holding
/// the play glyph, or a progress ring while the video loads or uploads.
class ChatVideoDisc extends StatelessWidget {
  const ChatVideoDisc({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: kChatVideoDisc,
    height: kChatVideoDisc,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.scrim.withValues(alpha: 0.5),
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

/// A ring filling with [value] (0–1, null spins) and the percentage inside.
class ChatVideoProgressRing extends StatelessWidget {
  const ChatVideoProgressRing({super.key, required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: kChatVideoDisc - context.spacing.md,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 2,
            color: c.onScrim,
            backgroundColor: c.onScrim.withValues(alpha: 0.25),
          ),
        ),
        if (value case final v?)
          Text(
            formatPercent(v),
            style: context.typography.captionSm.copyWith(
              color: c.onScrim,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// The upload's progress of an own video still being sent.
class ChatVideoUploadRing extends ConsumerWidget {
  const ChatVideoUploadRing({super.key, required this.messageGid});

  final String messageGid;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChatVideoProgressRing(
    // Null until the first chunk reports: the ring spins instead.
    value: ref.watch(chatUploadProgressProvider(messageGid)).value,
  );
}

/// A small dark pill in a corner of the frame (the video's time).
class ChatVideoPill extends StatelessWidget {
  const ChatVideoPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(s.md),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
        child: Text(
          text,
          style: context.typography.captionStrong.copyWith(color: c.onScrim),
        ),
      ),
    );
  }
}

/// A small round icon button in a corner of the frame (full screen).
class ChatVideoCornerButton extends StatelessWidget {
  const ChatVideoCornerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.scrim.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: onPressed,
          hoverColor: c.onScrim.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.all(s.sm),
            child: Icon(icon, size: s.xl2, color: c.onScrim),
          ),
        ),
      ),
    );
  }
}

/// The thin played / buffered line along the bottom of a playing video;
/// dragging it seeks.
class ChatVideoProgressLine extends StatelessWidget {
  const ChatVideoProgressLine({super.key, required this.player});

  final VideoPlayerController player;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return VideoProgressIndicator(
      player,
      allowScrubbing: true,
      padding: EdgeInsets.zero,
      colors: VideoProgressColors(
        playedColor: c.accent,
        bufferedColor: c.onScrim.withValues(alpha: 0.35),
        backgroundColor: c.onScrim.withValues(alpha: 0.15),
      ),
    );
  }
}
