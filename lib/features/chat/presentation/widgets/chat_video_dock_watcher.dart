import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_video_playback.dart';

/// Watches a chat video's frame in its scrolling list: once less than a
/// third of it shows while it plays, the video floats over the chat (the
/// mini player), and docks back when the frame is in view again. A frame
/// dropped from the list while playing floats it too.
class ChatVideoDockWatcher extends ConsumerStatefulWidget {
  const ChatVideoDockWatcher({
    super.key,
    required this.messageGid,
    required this.child,
  });

  final String messageGid;
  final Widget child;

  @override
  ConsumerState<ChatVideoDockWatcher> createState() =>
      _ChatVideoDockWatcherState();
}

class _ChatVideoDockWatcherState extends ConsumerState<ChatVideoDockWatcher> {
  late final ChatVideoPlaybackNotifier _playback;
  ScrollPosition? _scroll;

  @override
  void initState() {
    super.initState();
    // Kept for dispose, where `ref` can no longer be read.
    _playback = ref.read(chatVideoPlaybackProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_check);
      _scroll = scroll?..addListener(_check);
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_check);
    // After this frame: providers can't change while the tree is torn down.
    final playback = _playback;
    final gid = widget.messageGid;
    Future.microtask(() => playback.setFloating(gid, floating: true));
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    if (ref.read(chatVideoPlaybackProvider)?.messageGid != widget.messageGid) {
      return;
    }
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox) return;
    if (!box.attached || !viewport.attached) return;
    final frame = box.localToGlobal(Offset.zero) & box.size;
    final view = viewport.localToGlobal(Offset.zero) & viewport.size;
    final shown = frame.intersect(view);
    final visible = shown.isEmpty || frame.height <= 0
        ? 0.0
        : shown.height / frame.height;
    _playback.setFloating(widget.messageGid, floating: visible < 1 / 3);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
