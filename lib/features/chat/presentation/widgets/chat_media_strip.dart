import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_media_viewer_bar.dart';
import 'chat_shared_files.dart';

/// The chat's photos and videos, oldest first (as in the chat).
List<MessageContent> chatMediaOf(WidgetRef ref, ChatThreadKey thread) {
  final all = ref.watch(chatAttachmentsProvider(thread)).value ?? const [];
  return [for (final m in splitChatAttachments(all).media.reversed) m.content];
}

/// Where [item] is in [media], matched by its file (the same attachment can
/// come from the messages and from the chat's file list with other details
/// filled in); -1 when absent.
int indexOfChatMedia(List<MessageContent> media, MessageContent item) {
  int? idOf(MessageContent m) => switch (m) {
    ImageContent(:final fileId) when fileId > 0 => fileId,
    FileContent(:final fileId) when fileId > 0 => fileId,
    _ => null,
  };
  final id = idOf(item);
  return id == null
      ? media.indexOf(item)
      : media.indexWhere(
          (m) => m.runtimeType == item.runtimeType && idOf(m) == id,
        );
}

/// Along the bottom of the image and video viewers: the chat's photos and
/// videos as thumbnails, the one shown ([current]) outlined and scrolled into
/// view; a click shows another ([onPick]).
class ChatMediaStrip extends ConsumerStatefulWidget {
  const ChatMediaStrip({
    super.key,
    required this.thread,
    required this.current,
    required this.onPick,
  });

  final ChatThreadKey thread;
  final MessageContent current;
  final ValueChanged<MessageContent> onPick;

  @override
  ConsumerState<ChatMediaStrip> createState() => _ChatMediaStripState();
}

class _ChatMediaStripState extends ConsumerState<ChatMediaStrip> {
  final _scroll = ScrollController();
  MessageContent? _centred;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the strip most of its width left (-1) or right (1).
  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target =
        position.pixels + direction * position.viewportDimension * 0.8;
    _scroll.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Scrolls the shown item to the middle once the strip is laid out: at
  /// once the first time (a new viewer opens already in place — gliding in
  /// from the start would look like a jump), smoothly after that.
  void _centre(int index, double extent) {
    if (_centred == widget.current) return;
    final first = _centred == null;
    _centred = widget.current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final offset =
          (index * extent - (position.viewportDimension - extent) / 2).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      if (first) {
        _scroll.jumpTo(offset);
      } else {
        _scroll.animateTo(
          offset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final size = s.xl6 * 1.4;
    final height = size + s.md * 2;
    // Room kept while the list loads (a new viewer reads it again), so the
    // media above does not shift when the strip appears.
    if (!ref.watch(chatAttachmentsProvider(widget.thread)).hasValue) {
      return SizedBox(height: height);
    }
    final media = chatMediaOf(ref, widget.thread);
    if (media.length < 2) return const SizedBox.shrink();
    final extent = size + s.sm;
    final index = indexOfChatMedia(media, widget.current);
    if (index >= 0) _centre(index, extent);
    final l = AppL10n.of(context);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          ChatViewerButton(
            icon: PhosphorIconsLight.caretLeft,
            tooltip: l.chatPrevious,
            onPressed: () => _page(-1),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(vertical: s.md),
              itemExtent: extent,
              itemCount: media.length,
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.only(right: s.sm),
                child: _Thumb(
                  accountId: widget.thread.accountId,
                  content: media[i],
                  selected: i == index,
                  onTap: () => widget.onPick(media[i]),
                ),
              ),
            ),
          ),
          ChatViewerButton(
            icon: PhosphorIconsLight.caretRight,
            tooltip: l.chatNext,
            onPressed: () => _page(1),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({
    required this.accountId,
    required this.content,
    required this.selected,
    required this.onTap,
  });

  final String accountId;
  final MessageContent content;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final bytes = switch (content) {
      ImageContent() => ref.watch(
        chatAttachmentProvider((
          accountId: accountId,
          content: content,
          thumbnail: true,
        )),
      ),
      _ => ref.watch(
        chatVideoThumbnailProvider((accountId: accountId, video: content)),
      ),
    }.value;
    final radius = BorderRadius.circular(context.radii.sm);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          // The others recede so the shown one stands out.
          opacity: selected ? 1 : 0.55,
          // On top: the picture would cover a border drawn beneath it.
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? c.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: c.onScrim.withValues(alpha: 0.12)),
                  if (bytes case Ok(:final value))
                    Image.memory(
                      value,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  if (content is FileContent)
                    Center(
                      child: Icon(
                        PhosphorIconsFill.playCircle,
                        size: s.xl4,
                        color: c.onScrim,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
