import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/debug/app_talker.dart';
import '../../domain/entities/chat_message.dart';
import 'message_list_anchor.dart';

/// Brings a message row of the lazily built, reversed message list to the
/// centre and keeps it there for a moment.
///
/// The moving is done by [MessageJumpSliver] while the list is laid out, not
/// by scrolling between frames: a row far away is reached in one frame (the
/// rows passed on the way are never painted), and a row pushed off centre by
/// its neighbours growing (images, cards loading) is put back before that
/// frame is painted. Only a row already laid out near the screen is glided
/// to.
class MessageJump extends ChangeNotifier {
  /// How many older pages a jump may load to find its message.
  static const maxPages = 20;

  /// How long a revealed row is kept centred.
  static const _holdFor = Duration(seconds: 3);
  static const _highlightFor = Duration(seconds: 2);
  static const _glideFor = Duration(milliseconds: 300);

  /// A row that is in the list but never reached is let go after this.
  static const _giveUpAfter = Duration(seconds: 2);

  int? _target;
  bool _arrived = false;
  Duration? _heldSince;
  Completer<bool>? _done;

  /// Bumped by each jump and when the user takes over, so an older glide
  /// stops short of holding its row.
  int _generation = 0;

  /// Server id of the message being sought or held centred, or null.
  int? get target => _target;

  /// Aimed at a message not yet laid out where it belongs: the list paints
  /// nothing rather than the rows it passes on the way.
  bool get seeking => _target != null && !_arrived;

  /// The index among [rows] of the message [serverId], or -1.
  static int indexIn(List<Object> rows, int serverId) =>
      rows.indexWhere((r) => r is ChatMessage && r.serverId == serverId);

  /// Aims at message [serverId] before its rows are shown (a window is about
  /// to be loaded around it): the frame that brings them puts it centred,
  /// so they are never seen where the list was.
  void aim(int serverId) {
    _finish(false);
    _generation++;
    _target = serverId;
    _arrived = false;
    _heldSince = null;
    _done = Completer<bool>();
    notifyListeners();
  }

  /// Brings message [serverId] to the centre: glides there when its row is
  /// laid out already, else (or when [aim]ed) the list jumps there as it is
  /// laid out. False when it never got there.
  Future<bool> reveal(
    ScrollController scroll, {
    required int serverId,
    required List<Object> rows,
  }) async {
    if (_target != serverId || _done == null) {
      final glided = await _glide(scroll, serverId, rows);
      if (glided != null) return glided;
      aim(serverId);
    }
    final done = _done;
    if (done == null) return _arrived && _target == serverId;
    final found = await done.future.timeout(
      _giveUpAfter,
      onTimeout: () {
        if (identical(_done, done)) release();
        return false;
      },
    );
    if (!found) appTalker.warning('Chat jump: $serverId never came into view');
    return found;
  }

  /// Animates to the row of [serverId] when it is laid out; null when not.
  Future<bool?> _glide(
    ScrollController scroll,
    int serverId,
    List<Object> rows,
  ) async {
    if (!scroll.hasClients) return null;
    final index = indexIn(rows, serverId);
    final sliver = messageListSliver(scroll);
    if (index < 0 || sliver == null) return null;
    RenderBox? box;
    for (var c = sliver.firstChild; c != null; c = sliver.childAfter(c)) {
      if (sliver.indexOf(c) == index) box = c;
    }
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
    if (box == null || viewport == null) return null;
    release();
    final generation = _generation;
    final position = scroll.position;
    final to = viewport
        .getOffsetToReveal(box, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    await scroll.animateTo(to, duration: _glideFor, curve: Curves.easeOut);
    if (generation != _generation) return false;
    // Held from here on, like a row jumped to.
    _target = serverId;
    _arrived = true;
    _heldSince = null;
    notifyListeners();
    return true;
  }

  /// Stops the jump: the user scrolled or pressed in the list, the message
  /// was not found, or the list shows another chat. The list shows again.
  void release() {
    _generation++;
    _finish(false);
    if (_target == null) return;
    _target = null;
    notifyListeners();
  }

  /// From the list's layout: the row is centred.
  void arrive() {
    if (_arrived) return;
    _arrived = true;
    _finish(true);
  }

  /// From the list's layout, at frame time [now]: whether the row is still
  /// to be kept centred. Lets it go once held for [_holdFor].
  bool holds(Duration? now) {
    if (_target == null) return false;
    if (!_arrived || now == null) return true;
    final since = _heldSince ??= now;
    if (now - since <= _holdFor) return true;
    // Mid-layout: nothing to notify, the list simply stops correcting.
    _target = null;
    return false;
  }

  void _finish(bool found) {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete(found);
  }

  @override
  void dispose() {
    _finish(false);
    super.dispose();
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
