import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/chat_message.dart';

/// The sliver of the message list behind [scroll], holding its laid-out
/// rows and their offsets; null while it has none.
RenderSliverMultiBoxAdaptor? messageListSliver(ScrollController scroll) {
  RenderSliverMultiBoxAdaptor? found;
  void visit(RenderObject child) {
    if (found != null) return;
    if (child is RenderSliverMultiBoxAdaptor) {
      found = child;
    } else {
      child.visitChildren(visit);
    }
  }

  final root = scroll.position.context.storageContext.findRenderObject();
  if (root != null) visit(root);
  return found;
}

/// A message row on screen and how far it sits from the scroll position, so
/// the list can be put back where the reader was after rows are added below
/// it. Measured from the laid-out rows: the list's total extent is only an
/// estimate, and it moves as rows are added.
class MessageListAnchor {
  const MessageListAnchor._(this._gid, this._fromPixels);

  final String _gid;
  final double _fromPixels;

  /// The newest message row on screen, or null when none is laid out.
  static MessageListAnchor? capture(
    ScrollController scroll,
    List<Object> rows,
  ) {
    if (!scroll.hasClients) return null;
    final sliver = messageListSliver(scroll);
    final pixels = scroll.position.pixels;
    for (var child = sliver?.firstChild; child != null;) {
      final index = sliver!.indexOf(child);
      final offset = sliver.childScrollOffset(child);
      // Reversed: offsets grow upwards, so the first row reaching past the
      // scroll position is the one at the bottom edge.
      if (offset != null &&
          offset + child.size.height > pixels &&
          index < rows.length) {
        if (rows[index] case final ChatMessage m) {
          return MessageListAnchor._(m.gid, offset - pixels);
        }
      }
      child = sliver.childAfter(child);
    }
    return null;
  }

  /// Scrolls so the anchored row is as far from the scroll position as it
  /// was; does nothing when the row is no longer laid out.
  void restore(ScrollController scroll, List<Object> rows) {
    if (!scroll.hasClients) return;
    final index = rows.indexWhere((r) => r is ChatMessage && r.gid == _gid);
    final sliver = messageListSliver(scroll);
    if (index < 0 || sliver == null) return;
    for (var child = sliver.firstChild; child != null;) {
      if (sliver.indexOf(child) == index) {
        final offset = sliver.childScrollOffset(child);
        if (offset == null) return;
        final position = scroll.position;
        final target = (offset - _fromPixels).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((target - position.pixels).abs() > 0.5) scroll.jumpTo(target);
        return;
      }
      child = sliver.childAfter(child);
    }
  }
}
