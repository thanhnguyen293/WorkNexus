import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_typing_providers.dart';
import 'chat_style.dart';
import 'chat_typing_avatars.dart';
import 'chat_typing_label.dart';
import 'message_bubble_box.dart';
import 'typing_dots.dart';

/// The bottom row of the (reversed) message list, under the newest message:
/// it holds [ChatTypingBubble].
final class ChatTypingItem {
  const ChatTypingItem();
}

/// A received-style bubble of rising dots under the newest message while
/// anyone is typing, with who it is beside it. The row is always in the list
/// and grows in or closes, so messages move instead of being covered.
///
/// It only opens while the reader is at the newest messages ([active]):
/// growing out of sight under someone reading history would shift what they
/// are reading.
class ChatTypingBubble extends ConsumerStatefulWidget {
  const ChatTypingBubble({
    super.key,
    required this.thread,
    required this.style,
    required this.users,
    required this.showSenders,
    required this.active,
  });

  final ChatThreadKey thread;
  final ChatStyle style;
  final Map<int, ChatUser> users;
  final bool showSenders;
  final bool active;

  @override
  ConsumerState<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends ConsumerState<ChatTypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  late final CurvedAnimation _curve;

  /// Who is typing now, and who the bubble shows — the last non-empty roster,
  /// kept while it closes.
  List<int> _typing = const [];
  List<int> _shown = const [];

  @override
  void initState() {
    super.initState();
    // Exits are quicker than entries; the default animation behaviour also
    // shortens both when the platform asks for reduced motion. Made here,
    // not lazily: a first touch in `dispose` would look up a gone ancestor.
    _reveal = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
      reverseDuration: AppMotion.base,
    );
    _curve = CurvedAnimation(
      parent: _reveal,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    _typing = ref.read(chatTypingUsersProvider(widget.thread));
    if (widget.active && _typing.isNotEmpty) {
      _shown = _typing;
      _reveal.value = 1;
    }
  }

  @override
  void didUpdateWidget(ChatTypingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _curve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.active && _typing.isNotEmpty) {
      _shown = _typing;
      _reveal.forward();
      return;
    }
    _reveal.reverse().whenComplete(() {
      // Gone once closed: the dots stop and nothing is left to lay out.
      if (mounted && _reveal.isDismissed) {
        setState(() => _shown = const []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatTypingUsersProvider(widget.thread), (_, typing) {
      setState(() {
        _typing = typing;
        _sync();
      });
    });
    if (_shown.isEmpty) return const SizedBox.shrink();
    final label = chatTypingLabel(context, widget.users, _shown);
    return SizeTransition(
      sizeFactor: _curve,
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: _curve,
        child: Semantics(
          liveRegion: true,
          label: label,
          child: Tooltip(
            message: label,
            child: _TypingRow(
              style: widget.style,
              users: widget.users,
              typing: _shown,
              avatars: widget.showSenders || widget.style.avatarInDirectChats,
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar slot, the bubble, then anyone else typing — laid out like a
/// received message's row so the bubble lines up with the messages above.
class _TypingRow extends StatelessWidget {
  const _TypingRow({
    required this.style,
    required this.users,
    required this.typing,
    required this.avatars,
  });

  final ChatStyle style;
  final Map<int, ChatUser> users;
  final List<int> typing;
  final bool avatars;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final ink = style.ink(mine: false);
    final tailed = style.tail != null;
    final box = MessageBubbleBox(
      fill: style.bubbleFill(mine: false),
      hoverFill: ink.hoverFill,
      borderColor: style.bubbleBorder(mine: false),
      borderRadius: style.corners(
        mine: false,
        firstOfRun: true,
        lastOfRun: true,
        withTail: tailed,
      ),
      padding: style.padding,
      mine: false,
      tail: style.tail,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.xs, horizontal: s.xxs),
        child: TypingDots(color: ink.meta, size: s.sm),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl5, style.groupGap, s.xl5, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (avatars) ...[
            ChatTypingAvatar(style: style, users: users, userId: typing.first),
            SizedBox(width: s.md),
          ],
          // Always the run's only bubble, so a tailed style draws its tail
          // and the box makes its own room for it.
          box,
          if (typing.length > 1) ...[
            SizedBox(width: s.md),
            ChatTypingOthers(users: users, ids: typing.sublist(1)),
          ],
        ],
      ),
    );
  }
}
