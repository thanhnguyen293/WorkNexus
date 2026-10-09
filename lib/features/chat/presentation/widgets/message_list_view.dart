import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../providers/chat_providers.dart';
import 'chat_style.dart';
import 'list_extent_estimate.dart';
import 'message_jump.dart';
import 'message_list_item.dart';
import 'steady_extent_child_delegate.dart';

/// Laying out far past the viewport steadies the estimated list length.
const ScrollCacheExtent _kCacheExtent = ScrollCacheExtent.pixels(2000);

/// The reversed, lazily built list of [items] (newest first) under
/// [header] (load older / start of chat), reporting scroll metrics and
/// whether a mouse button is held to [MessageList].
class MessageListView extends StatelessWidget {
  const MessageListView({
    super.key,
    required this.thread,
    required this.scroll,
    required this.items,
    required this.style,
    required this.users,
    required this.summaries,
    required this.showSenders,
    required this.extent,
    required this.jump,
    required this.header,
    required this.onMetrics,
    required this.onMouseDown,
    required this.onMouseUp,
  });

  final ChatThreadKey thread;
  final ScrollController scroll;
  final List<Object> items;
  final ChatStyle style;
  final Map<int, ChatUser> users;
  final Map<int, ThreadSummary> summaries;
  final bool showSenders;
  final ListExtentEstimate extent;
  final MessageJump jump;
  final Widget header;
  final bool Function(ScrollMetrics metrics) onMetrics;
  final VoidCallback onMouseDown;
  final VoidCallback onMouseUp;

  @override
  Widget build(BuildContext context) {
    // Lets a message keep its row (and state) when newer ones push it up.
    final rows = {
      for (final (i, item) in items.indexed)
        if (item is ChatMessage) item.gid: i,
    };
    return Listener(
      onPointerDown: (e) {
        if (e.kind == PointerDeviceKind.mouse) onMouseDown();
      },
      onPointerUp: (_) => onMouseUp(),
      onPointerCancel: (_) => onMouseUp(),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => n.depth == 0 && onMetrics(n.metrics),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) => n.depth == 0 && onMetrics(n.metrics),
          child: ListView.custom(
            controller: scroll,
            reverse: true,
            scrollCacheExtent: _kCacheExtent,
            // Rows add their own side margins, so a highlighted row's tint
            // spans the full width.
            padding: EdgeInsets.symmetric(vertical: context.spacing.xl3),
            childrenDelegate: SteadyExtentChildDelegate(
              (context, i) => i == items.length
                  ? header
                  : MessageListItem(
                      key: switch (items[i]) {
                        final ChatMessage m => ValueKey(m.gid),
                        _ => null,
                      },
                      anchor: switch (items[i]) {
                        final ChatMessage m when m.gid == jump.targetGid =>
                          jump.anchor,
                        _ => null,
                      },
                      thread: thread,
                      items: items,
                      index: i,
                      style: style,
                      users: users,
                      summaries: summaries,
                      showSenders: showSenders,
                    ),
              estimate: extent,
              childCount: items.length + 1,
              findChildIndexCallback: (key) =>
                  key is ValueKey<String> ? rows[key.value] : null,
            ),
          ),
        ),
      ),
    );
  }
}
