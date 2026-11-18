import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../providers/chat_providers.dart';
import 'chat_style.dart';
import 'chat_typing_bubble.dart';
import 'list_extent_estimate.dart';
import 'list_row_widget_cache.dart';
import 'message_jump.dart';
import 'message_list_item.dart';
import 'steady_extent_child_delegate.dart';

/// The typing row's key; no message gid looks like it.
const String _kTypingKey = '#typing';

/// Laying out far past the viewport steadies the estimated list length.
const double _kCacheExtent = 2000;

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
    required this.typingActive,
    required this.extent,
    required this.jump,
    required this.rowCache,
    required this.arrivals,
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

  /// The reader is at the newest messages: the typing row may open.
  final bool typingActive;
  final ListExtentEstimate extent;
  final MessageJump jump;
  final ListRowWidgetCache rowCache;

  /// Gids of messages that just arrived; a row built for one eases in, once
  /// (the gid is taken out as its row is built).
  final Set<String> arrivals;
  final Widget header;
  final bool Function(ScrollMetrics metrics) onMetrics;
  final VoidCallback onMouseDown;
  final VoidCallback onMouseUp;

  @override
  Widget build(BuildContext context) {
    // Lets a message keep its row (and state) when newer ones push it up.
    final rows = {
      for (final (i, item) in items.indexed)
        if (item is ChatMessage)
          item.gid: i
        else if (item is ChatTypingItem)
          _kTypingKey: i,
    };
    rowCache.retain(rows.keys.toSet());
    Widget row(BuildContext context, int i) {
      if (i == items.length) return header;
      final item = items[i];
      if (item is ChatTypingItem) {
        return ChatTypingBubble(
          key: const ValueKey(_kTypingKey),
          thread: thread,
          style: style,
          users: users,
          showSenders: showSenders,
          active: typingActive,
        );
      }
      if (item is! ChatMessage) {
        return MessageListItem(
          thread: thread,
          item: item,
          style: style,
          users: users,
          showSenders: showSenders,
        );
      }
      final first = !chatSameRun(
        i + 1 < items.length ? items[i + 1] : null,
        item,
      );
      final last = !chatSameRun(i > 0 ? items[i - 1] : null, item);
      final summary = summaries[item.serverId];
      final anchor = item.gid == jump.targetGid ? jump.anchor : null;
      final arriving = arrivals.remove(item.gid);
      return rowCache.row(
        item.gid,
        [
          item,
          first,
          last,
          summary,
          anchor,
          arriving,
          style,
          users,
          showSenders,
          thread,
        ],
        () => MessageListItem(
          key: ValueKey(item.gid),
          thread: thread,
          item: item,
          style: style,
          users: users,
          showSenders: showSenders,
          firstOfRun: first,
          lastOfRun: last,
          summary: summary,
          anchor: anchor,
          arriving: arriving,
        ),
      );
    }

    return Listener(
      onPointerDown: (e) {
        // The user takes over: a jumped-to row stops being held centred.
        jump.release();
        if (e.kind == PointerDeviceKind.mouse) onMouseDown();
      },
      onPointerSignal: (_) => jump.release(),
      onPointerPanZoomStart: (_) => jump.release(),
      onPointerUp: (_) => onMouseUp(),
      onPointerCancel: (_) => onMouseUp(),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => n.depth == 0 && onMetrics(n.metrics),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) => n.depth == 0 && onMetrics(n.metrics),
          child: ListView.custom(
            scrollCacheExtent: const ScrollCacheExtent.pixels(_kCacheExtent),
            controller: scroll,
            reverse: true,
            // Rows add their own side margins, so a highlighted row's tint
            // spans the full width.
            padding: EdgeInsets.symmetric(vertical: context.spacing.xl3),
            childrenDelegate: SteadyExtentChildDelegate(
              row,
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
