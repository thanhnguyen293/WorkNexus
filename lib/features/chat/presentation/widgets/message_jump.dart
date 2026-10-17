import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/debug/app_talker.dart';
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

  /// Bumped by each jump and when the user takes over the list, so an older
  /// jump stops holding its row in place.
  int _generation = 0;

  /// How many older pages a jump may load to find its message.
  static const maxPages = 20;

  static const _maxAttempts = 12;

  /// How long a revealed row is kept centred.
  static const _holdFor = Duration(seconds: 3);
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
    final generation = ++_generation;
    rebuild();
    final found = await _seek(scroll, gid, rows, generation, animate: true);
    if (found) {
      _hold(scroll, gid, rows, generation);
    } else {
      appTalker.warning('Chat jump: $gid never came into view');
    }
    return found;
  }

  /// Jumps to row [gid]'s estimated offset until the row is built, then
  /// centres it.
  Future<bool> _seek(
    ScrollController scroll,
    String gid,
    List<Object> Function() rows,
    int generation, {
    required bool animate,
  }) async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      // Asked for: called back from a frame (holding the row), waiting for
      // the next one would never end on a list with nothing else to draw.
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (generation != _generation) return false;
      final row = anchor.currentContext;
      if (row != null && row.mounted) {
        await Scrollable.ensureVisible(
          row,
          alignment: 0.5,
          duration: animate ? _duration : Duration.zero,
          curve: Curves.easeOut,
        );
        return true;
      }
      final all = rows();
      final index = all.indexWhere((r) => r is ChatMessage && r.gid == gid);
      if (index < 0 || !scroll.hasClients) return false;
      final position = scroll.position;
      // Far away at first: jump to its share of the scroll extent. Close by,
      // or once that missed, step from the rows that are laid out (their
      // offsets are real, unlike an estimate over rows never measured).
      final step = attempt == 0 && animate ? null : _stepTowards(scroll, index);
      // Reversed: offset 0 is the newest row (index 0).
      final total = position.maxScrollExtent + position.viewportDimension;
      final target =
          step ??
          total * (index + 0.5) / all.length - position.viewportDimension / 2;
      scroll.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
    return false;
  }

  /// An offset a viewport closer to row [index] than the rows laid out now:
  /// the furthest laid-out row on its side brought to the near edge. Null
  /// when the list has no laid-out rows to step from.
  static double? _stepTowards(ScrollController scroll, int index) {
    final sliver = _sliverOf(scroll);
    final first = sliver?.firstChild;
    final last = sliver?.lastChild;
    if (sliver == null || first == null || last == null) return null;
    final viewport = scroll.position.viewportDimension;
    if (index > sliver.indexOf(last)) {
      // Older, further up a reversed list.
      return sliver.childScrollOffset(last);
    }
    if (index < sliver.indexOf(first)) {
      final offset = sliver.childScrollOffset(first);
      if (offset == null) return null;
      return offset + first.size.height - viewport;
    }
    return null;
  }

  /// The list's sliver, holding its laid-out rows and their offsets.
  static RenderSliverMultiBoxAdaptor? _sliverOf(ScrollController scroll) {
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

  /// The user scrolled or pressed in the list: a row being held centred is
  /// let go.
  void release() => _generation++;

  /// Keeps the revealed row centred for a moment. Shown for the first time,
  /// the rows around it are still being measured — names, images, cards
  /// that load — and as they grow they push it off centre, even out of the
  /// built rows (on a later jump they are known, which is why only the first
  /// one landed wrong). Checked after each frame, so a row that grew is put
  /// back before it is seen out of place; stops at the next jump or when
  /// the user scrolls.
  void _hold(
    ScrollController scroll,
    String gid,
    List<Object> Function() rows,
    int generation,
  ) {
    Duration? start;
    var seeking = false;
    void check(Duration now) {
      start ??= now;
      if (now - start! > _holdFor || generation != _generation) return;
      if (!scroll.hasClients) return;
      final box = anchor.currentContext?.findRenderObject();
      final viewport = box != null && box.attached
          ? RenderAbstractViewport.maybeOf(box)
          : null;
      if (box != null && viewport != null) {
        final position = scroll.position;
        final centred = viewport
            .getOffsetToReveal(box, 0.5)
            .offset
            .clamp(position.minScrollExtent, position.maxScrollExtent);
        if ((centred - position.pixels).abs() > 1) position.jumpTo(centred);
      } else if (!seeking) {
        seeking = true;
        unawaited(
          _seek(
            scroll,
            gid,
            rows,
            generation,
            animate: false,
          ).whenComplete(() => seeking = false),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback(check);
    }

    WidgetsBinding.instance.addPostFrameCallback(check);
  }

  /// Takes the pending jump [request] — cleared, so it runs once — and
  /// hands its message id to [jump].
  static void take(
    StateProvider<int?> request,
    WidgetRef ref,
    void Function(int serverId) jump,
  ) {
    final pending = ref.read(request.notifier);
    final id = pending.state;
    if (id == null) return;
    pending.state = null;
    jump(id);
  }

  /// Highlights message [serverId] through [highlight] for a moment.
  static Future<void> flash(
    StateController<int?> highlight,
    int serverId,
  ) async {
    highlight.state = serverId;
    // Counted from when it is on screen: after a notification tap the app
    // may still be coming to the front, drawing no frames yet.
    await _untilShown();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(_highlightFor);
    if (highlight.mounted && highlight.state == serverId) {
      highlight.state = null;
    }
  }

  /// Waits (a few seconds at most) for the app to be in front and drawing.
  static Future<void> _untilShown() async {
    final state = WidgetsBinding.instance.lifecycleState;
    // Unknown (not reported yet, e.g. in tests) counts as shown.
    if (state == null || state == AppLifecycleState.resumed) return;
    final shown = Completer<void>();
    final listener = AppLifecycleListener(onResume: shown.complete);
    await shown.future.timeout(_waitForFront, onTimeout: () {});
    listener.dispose();
  }

  static const _waitForFront = Duration(seconds: 5);
}
