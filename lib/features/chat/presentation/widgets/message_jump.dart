import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/chat_message.dart';

/// Brings a row of a lazily built, reversed message list into view. Rows far
/// from the viewport are not built, so it first jumps to the row's estimated
/// offset (its share of the scroll extent), lets the frame build the rows
/// around it, and repeats until the row exists — then scrolls it to the
/// centre.
class MessageJump {
  /// Put on the target row (and only on it) while a jump runs.
  final GlobalKey anchor = GlobalKey();

  /// The message gid the [anchor] belongs on, or null.
  String? targetGid;

  /// How many older pages a jump may load to find its message.
  static const maxPages = 20;

  static const _maxAttempts = 12;
  static const _highlightFor = Duration(seconds: 2);
  static const _duration = Duration(milliseconds: 300);

  /// Scrolls the row of message [gid] into view: marks it as the target,
  /// lets [rebuild] put the [anchor] on it, then finds it among [rows]. False
  /// when it never got built (the list went away or changed).
  Future<bool> reveal(
    ScrollController scroll, {
    required String gid,
    required List<Object> Function() rows,
    required VoidCallback rebuild,
  }) async {
    targetGid = gid;
    rebuild();
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final row = anchor.currentContext;
      if (row != null && row.mounted) {
        await Scrollable.ensureVisible(
          row,
          alignment: 0.5,
          duration: _duration,
          curve: Curves.easeOut,
        );
        return true;
      }
      final all = rows();
      final index = all.indexWhere((r) => r is ChatMessage && r.gid == gid);
      if (index < 0 || !scroll.hasClients) return false;
      final position = scroll.position;
      // Reversed: offset 0 is the newest row (index 0).
      final total = position.maxScrollExtent + position.viewportDimension;
      final estimate =
          total * (index + 0.5) / all.length - position.viewportDimension / 2;
      scroll.jumpTo(
        estimate.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
    return false;
  }

  /// Highlights message [serverId] through [highlight] for a moment.
  static Future<void> flash(
    StateController<int?> highlight,
    int serverId,
  ) async {
    highlight.state = serverId;
    await Future<void>.delayed(_highlightFor);
    if (highlight.mounted && highlight.state == serverId) {
      highlight.state = null;
    }
  }
}
