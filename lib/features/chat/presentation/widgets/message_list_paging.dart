import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';
import 'message_jump.dart';
import 'message_list.dart';

/// [MessageList]'s paging: older pages at the top, newer ones at the bottom
/// of a jump window, and jumps to a message — in place when it is loaded,
/// else through a window fetched around it.
mixin MessageListPaging on ConsumerState<MessageList> {
  ScrollController get scroll;
  MessageJump get jump;

  /// The rows of the last build, for finding a message to jump to.
  List<Object> get rows;

  bool loadingOlder = false;
  bool reachedStart = false;
  bool loadingNewer = false;

  /// A jump window found nothing newer and could not join the timeline:
  /// it stops asking (the jump-to-latest button still goes there).
  bool newerExhausted = false;

  /// Set when a load failed: automatic loading stops (no retry loop while
  /// offline) and the header offers a button to try again.
  bool loadFailed = false;

  /// A mouse button is held: likely dragging the scrollbar thumb. Older pages
  /// wait until it is released: the thumb maps its offset to a scroll position
  /// through the list's length, so growing the list mid-drag throws the
  /// content far from the cursor.
  bool mouseDown = false;

  /// Older messages fetched while the mouse was held, shown on release.
  int _pendingRows = 0;

  /// While newer rows are being added under the reader: their distance from
  /// the top of the list, held once the rows are laid out.
  double? _keepFromTop;

  ChatMessageWindow get window =>
      ref.read(chatMessageWindowProvider(widget.thread));

  List<ChatMessage> get _shown =>
      ref.read(chatMessagesProvider(widget.thread)).value ?? const [];

  void resetPaging() {
    loadingOlder = false;
    reachedStart = false;
    loadingNewer = false;
    newerExhausted = false;
    loadFailed = false;
    _pendingRows = 0;
    _keepFromTop = null;
  }

  Future<void> loadOlder() async {
    final t = widget.thread;
    final shown = _shown;
    final inWindow = window is AroundWindow;
    setState(() {
      loadingOlder = true;
      loadFailed = false;
    });
    final result = await ref
        .read(chatControllerProvider)
        .loadOlder(
          t.accountId,
          t.chatGid,
          oldestShown: shown.firstOrNull,
          inWindow: inWindow,
        );
    if (!mounted || widget.thread != t) return;
    setState(() => loadingOlder = false);
    switch (result) {
      case Ok(:final value) when value > 0:
        _pendingRows += math.min(value, ChatController.pageSize);
        showPending();
      // Nothing was cached yet: that call fetched the latest page, which is
      // not the start of the chat.
      case Ok() when shown.isEmpty:
        break;
      case Ok():
        setState(() => reachedStart = true);
      case Err(:final failure):
        setState(() => loadFailed = true);
        showChatFailure(context, failure);
    }
  }

  /// Shows [_pendingRows] more older messages — unless the mouse is held
  /// (likely on the scrollbar thumb): growing the list mid-drag throws the
  /// content away from the cursor, so they wait for the release.
  void showPending() {
    if (_pendingRows == 0 || mouseDown) return;
    final state = ref.read(chatMessageWindowProvider(widget.thread).notifier);
    state.state = switch (state.state) {
      LiveWindow() => LiveWindow(_shown.length + _pendingRows),
      final AroundWindow w => w.copyWith(from: w.from - _pendingRows),
    };
    _pendingRows = 0;
  }

  /// In a jump window, fetches the messages after the newest one shown;
  /// with none left, the window joins the timeline and reads on as usual.
  Future<void> loadNewer() async {
    final t = widget.thread;
    final w = window;
    final newest = _shown.lastOrNull;
    if (w is! AroundWindow || newest == null) return;
    setState(() => loadingNewer = true);
    final result = await ref
        .read(chatControllerProvider)
        .loadNewer(
          t.accountId,
          t.chatGid,
          newestShown: newest,
          windowFrom: w.from,
        );
    if (!mounted || widget.thread != t) return;
    setState(() => loadingNewer = false);
    final state = ref.read(chatMessageWindowProvider(t).notifier);
    switch (result) {
      case Ok(value: (added: final added, joined: _)) when added > 0:
        _holdPlace(() => state.state = w.copyWith(to: w.to + added));
      case Ok(value: (added: _, joined: final int joined)):
        _holdPlace(() => state.state = LiveWindow(joined));
      case Ok():
        setState(() => newerExhausted = true);
      case Err(:final failure):
        setState(() => newerExhausted = true);
        showChatFailure(context, failure);
    }
  }

  /// Rows added at the bottom of a reversed list push the ones being read
  /// up; [update] adds them, then the list scrolls by as much to hold them.
  void _holdPlace(VoidCallback update) {
    if (scroll.hasClients) {
      final position = scroll.position;
      _keepFromTop = position.maxScrollExtent - position.pixels;
    }
    update();
  }

  /// Called when the shown messages change: restores the place held by
  /// [_holdPlace] once the new rows are laid out.
  void onShownChanged() {
    final keep = _keepFromTop;
    if (keep == null) return;
    _keepFromTop = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final position = scroll.position;
      scroll.jumpTo(
        (position.maxScrollExtent - keep).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  /// Leaves a jump window for the newest messages, scrolled to the bottom.
  void backToLatest() {
    ref.read(chatMessageWindowProvider(widget.thread).notifier).state =
        const LiveWindow(ChatController.pageSize);
    setState(resetPaging);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  /// Scrolls to message [serverId] and highlights it. Not loaded yet: a
  /// window is fetched around it (stepping back page by page only when it
  /// cannot be placed that way).
  Future<void> jumpTo(int serverId) async {
    final t = widget.thread;
    await ref.read(chatMessagesProvider(t).future); // A chat just opened.
    if (!mounted || widget.thread != t) return;
    var target = _shown.where((m) => m.serverId == serverId).firstOrNull;
    if (target == null) {
      final around = await ref
          .read(chatControllerProvider)
          .loadAround(t.accountId, t.chatGid, serverId);
      if (!mounted || widget.thread != t) return;
      if (around case Ok(value: final span?)) {
        setState(resetPaging);
        ref.read(chatMessageWindowProvider(t).notifier).state = AroundWindow(
          from: span.from,
          to: span.to,
        );
        final shown = await ref.read(chatMessagesProvider(t).future);
        target = shown.where((m) => m.serverId == serverId).firstOrNull;
      } else {
        target = await _stepBackTo(serverId);
      }
    }
    if (!mounted || widget.thread != t) return;
    if (target == null) {
      showChatSnack(context, AppL10n.of(context).chatJumpNotFound);
      return;
    }
    final found = await jump.reveal(
      scroll,
      gid: target.gid,
      rows: () => rows,
      rebuild: () => setState(() {}),
    );
    if (!mounted || !found) return;
    await MessageJump.flash(
      ref.read(chatHighlightedMessageProvider(t).notifier),
      serverId,
    );
  }

  /// Loads older pages until message [serverId] is shown, within
  /// [MessageJump.maxPages]; null when it never turns up.
  Future<ChatMessage?> _stepBackTo(int serverId) async {
    final t = widget.thread;
    for (var page = 0; page < MessageJump.maxPages; page++) {
      if (!mounted || widget.thread != t) return null;
      final target = _shown.where((m) => m.serverId == serverId).firstOrNull;
      if (target != null) return target;
      if (reachedStart || loadFailed) return null;
      if (!loadingOlder) await loadOlder();
      await WidgetsBinding.instance.endOfFrame;
    }
    return _shown.where((m) => m.serverId == serverId).firstOrNull;
  }
}
