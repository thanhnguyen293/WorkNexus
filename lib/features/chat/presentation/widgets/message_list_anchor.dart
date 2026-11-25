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
/// it (while they are laid out, before they are painted). Measured from the laid-out rows: the list's total extent is only an
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
          // Its top edge: rows added below change only its bottom (it is
          // no longer the last of its run), never where its text starts.
          return MessageListAnchor._(
            m.gid,
            offset + child.size.height - pixels,
          );
        }
      }
      child = sliver.childAfter(child);
    }
    return null;
  }

  /// The anchored row's index among [rows], or -1 when it is gone.
  int indexIn(List<Object> rows) =>
      rows.indexWhere((r) => r is ChatMessage && r.gid == _gid);

  /// The scroll position that puts the row back where it was, given where
  /// its top edge now is ([rowEnd], in the list's offsets).
  double pixelsFor(double rowEnd) => rowEnd - _fromPixels;
}
