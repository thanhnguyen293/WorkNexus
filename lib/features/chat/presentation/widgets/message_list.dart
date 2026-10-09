import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';
import 'chat_style.dart';
import 'list_extent_estimate.dart';
import 'message_jump.dart';
import 'message_list_header.dart';
import 'message_list_item.dart';
import 'message_list_view.dart';
import 'scroll_to_latest_button.dart';

/// The messages of one chat, newest at the bottom. Earlier messages load on
/// their own as the user scrolls near the top. New messages arriving while it
/// is open are marked read.
class MessageList extends ConsumerStatefulWidget {
  const MessageList({
    super.key,
    required this.thread,
    required this.showSenders,
  });

  final ChatThreadKey thread;
  final bool showSenders;

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

/// How close (in pixels) to the oldest loaded message the user may scroll
/// before the next page is fetched, so it is usually there before they reach it.
const double _kLoadOlderThreshold = 600;

/// Distance from the newest message that shows the jump-to-latest button.
const double _kAwayThreshold = 400;

/// Further than this from the bottom, jumping is better than a long animation.
const double _kAnimateLimit = 4000;

const Duration _kScrollDuration = Duration(milliseconds: 250);

class _MessageListState extends ConsumerState<MessageList> {
  final _scroll = ScrollController();
  final _extent = ListExtentEstimate();
  bool _loadingOlder = false;
  bool _reachedStart = false;

  /// Set when a load failed: automatic loading stops (no retry loop while
  /// offline) and the header offers a button to try again.
  bool _loadFailed = false;

  /// Scrolled up far enough to show the jump-to-latest button.
  bool _away = false;

  /// Messages that arrived since the user scrolled away from the bottom.
  int _unseen = 0;

  /// A mouse button is held: likely dragging the scrollbar thumb. Older pages
  /// wait until it is released: the thumb maps its offset to a scroll position
  /// through the list's length, so growing the list mid-drag throws the
  /// content far from the cursor.
  bool _mouseDown = false;

  /// Older messages fetched while the mouse was held, shown on release.
  int _pendingRows = 0;

  final _jump = MessageJump();

  /// The rows of the last build, for finding a message to jump to.
  List<Object> _items = const [];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread != widget.thread) {
      _loadingOlder = false;
      _reachedStart = false;
      _loadFailed = false;
      _away = false;
      _unseen = 0;
      _pendingRows = 0;
      _extent.reset();
    }
  }

  /// Fires on scrolling and on content/viewport size changes, which also
  /// covers a first page too short to fill the screen.
  bool _onScrollMetrics(ScrollMetrics metrics) {
    // Reversed list: 0 is the newest message.
    if ((metrics.pixels > _kAwayThreshold) != _away) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Read again (several may be queued in one frame); not after dispose.
        if (!mounted || !_scroll.hasClients) return;
        final away = _scroll.position.pixels > _kAwayThreshold;
        if (away == _away) return;
        setState(() {
          _away = away;
          if (!away) _unseen = 0;
        });
      });
    }
    if (metrics.extentAfter < _kLoadOlderThreshold &&
        !_mouseDown &&
        !_loadingOlder &&
        !_reachedStart &&
        !_loadFailed &&
        !ref.read(chatMessagesProvider(widget.thread)).isLoading) {
      // Not during layout: loading calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loadingOlder && !_mouseDown) _loadOlder();
      });
    }
    return false;
  }

  Future<void> _loadOlder() async {
    final t = widget.thread;
    final shown = ref.read(chatMessagesProvider(t)).value ?? const [];
    setState(() {
      _loadingOlder = true;
      _loadFailed = false;
    });
    final result = await ref
        .read(chatControllerProvider)
        .loadOlder(t.accountId, t.chatGid, oldestShown: shown.firstOrNull);
    if (!mounted || widget.thread != t) return;
    setState(() => _loadingOlder = false);
    switch (result) {
      case Ok(:final value) when value > 0:
        _pendingRows += math.min(value, ChatController.pageSize);
        _showPending();
      // Nothing was cached yet: that call fetched the latest page, which is
      // not the start of the chat.
      case Ok() when shown.isEmpty:
        break;
      case Ok():
        setState(() => _reachedStart = true);
      case Err(:final failure):
        setState(() => _loadFailed = true);
        showChatFailure(context, failure);
    }
  }

  /// Shows [_pendingRows] more older messages — unless the mouse is held
  /// (likely on the scrollbar thumb): growing the list mid-drag throws the
  /// content away from the cursor, so they wait for the release.
  void _showPending() {
    if (_pendingRows == 0 || _mouseDown) return;
    final t = widget.thread;
    final shown = ref.read(chatMessagesProvider(t)).value?.length ?? 0;
    ref.read(chatMessageLimitProvider(t).notifier).state = shown + _pendingRows;
    _pendingRows = 0;
  }

  /// Scrolls to message [serverId] (loading older pages) and highlights it.
  Future<void> _jumpTo(int serverId) async {
    final t = widget.thread;
    await ref.read(chatMessagesProvider(t).future); // A chat just opened.
    ChatMessage? target;
    for (var page = 0; target == null; page++) {
      if (!mounted || widget.thread != t) return;
      final shown = ref.read(chatMessagesProvider(t)).value ?? const [];
      target = shown.where((m) => m.serverId == serverId).firstOrNull;
      if (target != null) break;
      if (_reachedStart || _loadFailed || page >= MessageJump.maxPages) {
        showChatSnack(context, AppL10n.of(context).chatJumpNotFound);
        return;
      }
      if (!_loadingOlder) await _loadOlder();
      await WidgetsBinding.instance.endOfFrame;
    }
    final found = await _jump.reveal(
      _scroll,
      gid: target.gid,
      rows: () => _items,
      rebuild: () => setState(() {}),
    );
    if (!mounted || !found) return;
    await MessageJump.flash(
      ref.read(chatHighlightedMessageProvider(t).notifier),
      serverId,
    );
  }

  void _onMouseUp() {
    _mouseDown = false;
    _showPending();
    if (_scroll.hasClients) _onScrollMetrics(_scroll.position);
  }

  void _scrollToLatest() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset > _kAnimateLimit) return _scroll.jumpTo(0);
    _scroll.animateTo(0, duration: _kScrollDuration, curve: Curves.easeOut);
  }

  /// Newer messages at the bottom: count them while the user reads older
  /// ones, or follow them down when the user sent one (from any device).
  void _onMessages(List<ChatMessage> before, List<ChatMessage> after) {
    final t = widget.thread;
    if (after.length > before.length) {
      ref.read(chatControllerProvider).markRead(t.accountId, t.chatGid);
    }
    final newest = before.lastOrNull?.gid;
    if (newest == null || after.isEmpty || after.last.gid == newest) return;
    final at = after.indexWhere((m) => m.gid == newest);
    if (at < 0) return;
    final arrived = after.sublist(at + 1);
    final self = ref.read(chatSelfUserIdProvider(t.accountId)).value;
    if (arrived.any((m) => m.senderId == self)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    } else if (_away) {
      setState(() => _unseen += arrived.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    ref.listen(
      chatMessagesProvider(t),
      (previous, next) =>
          _onMessages(previous?.value ?? const [], next.value ?? const []),
    );
    // A jump asked for while shown, or before the list existed (tapping a
    // notification opens the chat first): taken once, after this frame.
    if (ref.watch(chatJumpRequestProvider(t)) != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => MessageJump.take(chatJumpRequestProvider(t), ref, _jumpTo),
      );
    }
    // Kept alive for [_onMessages], which reads it.
    ref.watch(chatSelfUserIdProvider(t.accountId));
    final messagesAsync = ref.watch(chatMessagesProvider(t));
    final users =
        ref.watch(chatUsersProvider(t.accountId)).asData?.value ??
        const <int, ChatUser>{};
    // `value`, not `asData`: while a bigger page loads (the limit grew) the
    // provider is reloading and `asData` is null. Dropping to the spinner
    // then would unmount the list, lose the scroll position and — with the
    // fresh list near its top — trigger the next page, flashing forever.
    final messages = messagesAsync.value ?? const <ChatMessage>[];
    if (messagesAsync.isLoading && messages.isEmpty) {
      return const AppInlineSpinner();
    }
    final summaries = ref.watch(chatThreadSummariesProvider(t));
    final style = ChatStyle.watch(ref, context);
    final items = _items = chatListItems(messages, style.separatorGap);
    final list = MessageListView(
      thread: t,
      scroll: _scroll,
      items: items,
      style: style,
      users: users,
      summaries: summaries,
      showSenders: widget.showSenders,
      extent: _extent,
      jump: _jump,
      header: MessageListHeader(
        reachedStart: _reachedStart,
        failed: _loadFailed,
        onLoadOlder: _loadOlder,
      ),
      onMetrics: _onScrollMetrics,
      onMouseDown: () => _mouseDown = true,
      onMouseUp: _onMouseUp,
    );
    final s = context.spacing;
    return Stack(
      children: [
        list,
        Positioned(
          right: s.xl5,
          bottom: s.xl3,
          child: ScrollToLatestButton(
            visible: _away,
            unseen: _unseen,
            onPressed: _scrollToLatest,
          ),
        ),
      ],
    );
  }
}
