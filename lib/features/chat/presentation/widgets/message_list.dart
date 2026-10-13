import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_style.dart';
import 'chat_typing_bubble.dart';
import 'list_extent_estimate.dart';
import 'message_jump.dart';
import 'message_list_header.dart';
import 'message_list_item.dart';
import 'message_list_paging.dart';
import 'message_list_view.dart';
import 'scroll_to_latest_button.dart';

/// The messages of one chat, newest at the bottom. Earlier messages load on
/// their own as the user scrolls near the top — and, in a window jumped to
/// far back, later ones near the bottom. New messages are marked read once
/// they are on screen: right away at the bottom, or when the user scrolls
/// back down from older ones.
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

/// How close (in pixels) to either end of the loaded messages the user may
/// scroll before the next page is fetched, so it is usually there in time.
const double _kLoadThreshold = 600;

/// Distance from the newest message that shows the jump-to-latest button.
const double _kAwayThreshold = 400;

/// Further than this from the bottom, jumping is better than a long animation.
const double _kAnimateLimit = 4000;

const Duration _kScrollDuration = AppMotion.slow;

class _MessageListState extends ConsumerState<MessageList>
    with MessageListPaging {
  final _scroll = ScrollController();
  final _extent = ListExtentEstimate();
  final _jump = MessageJump();

  /// Scrolled up far enough to show the jump-to-latest button.
  bool _away = false;

  /// Messages that arrived since the user scrolled away from the bottom.
  int _unseen = 0;

  List<Object> _items = const [];

  @override
  ScrollController get scroll => _scroll;

  @override
  MessageJump get jump => _jump;

  @override
  List<Object> get rows => _items;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread != widget.thread) {
      resetPaging();
      _away = false;
      _unseen = 0;
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
        if (!away) _markReadIfSeen();
      });
    }
    final idle =
        !mouseDown &&
        !loadFailed &&
        !ref.read(chatMessagesProvider(widget.thread)).isLoading;
    if (idle &&
        metrics.extentAfter < _kLoadThreshold &&
        !loadingOlder &&
        !reachedStart) {
      // Not during layout: loading calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !loadingOlder && !mouseDown) loadOlder();
      });
    }
    if (idle &&
        window is AroundWindow &&
        metrics.extentBefore < _kLoadThreshold &&
        !loadingNewer &&
        !newerExhausted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !loadingNewer && !mouseDown) loadNewer();
      });
    }
    return false;
  }

  void _onMouseUp() {
    mouseDown = false;
    showPending();
    if (_scroll.hasClients) _onScrollMetrics(_scroll.position);
  }

  void _scrollToLatest() {
    if (window is AroundWindow) return backToLatest();
    if (!_scroll.hasClients) return;
    if (_scroll.offset > _kAnimateLimit) return _scroll.jumpTo(0);
    _scroll.animateTo(0, duration: _kScrollDuration, curve: Curves.easeOut);
  }

  int _unreadOf(AsyncValue<List<ChatConversation>> chats) =>
      chats.value
          ?.where((c) => c.gid == widget.thread.chatGid)
          .firstOrNull
          ?.unreadCount ??
      0;

  /// Marks the chat read while its newest messages are on screen — not while
  /// the user reads older ones, nor in a window jumped far back.
  void _markReadIfSeen() {
    if (_away || window is AroundWindow) return;
    final t = widget.thread;
    if (_unreadOf(ref.read(chatConversationsProvider(t.accountId))) == 0) {
      return;
    }
    ref.read(chatControllerProvider).markRead(t.accountId, t.chatGid);
  }

  /// Newer messages at the bottom: count them while the user reads older
  /// ones, or follow them down when the user sent one (from any device).
  /// Not in a jump window: rows it adds at the bottom are older history.
  void _onMessages(List<ChatMessage> before, List<ChatMessage> after) {
    onShownChanged();
    // Scroll events seen while these were loading were ignored; with rows
    // that may not change the list's height (a jump window replacing the
    // newest page), none may follow — so look at where the list is now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _onScrollMetrics(_scroll.position);
    });
    // Back from a jump window to the latest messages.
    _markReadIfSeen();
    final t = widget.thread;
    if (window is AroundWindow) return;
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
    // Not from the message rows: a full live page keeps its length as new
    // ones push old ones out, and the chat's last-message index moves only
    // after the rows are stored — so unread is known here, not there.
    ref.listen(chatConversationsProvider(t.accountId).select(_unreadOf), (
      _,
      unread,
    ) {
      if (unread > 0) _markReadIfSeen();
    });
    // A jump asked for while shown, or before the list existed (tapping a
    // notification opens the chat first): taken once, after this frame.
    if (ref.watch(chatJumpRequestProvider(t)) != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => MessageJump.take(chatJumpRequestProvider(t), ref, jumpTo),
      );
    }
    // Kept alive for [_onMessages], which reads it.
    ref.watch(chatSelfUserIdProvider(t.accountId));
    final inWindow = ref.watch(chatMessageWindowProvider(t)) is AroundWindow;
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
    if (messagesAsync.hasError && messages.isEmpty) {
      return AppStateView.error(
        onRetry: () => ref.invalidate(chatMessagesProvider(t)),
      );
    }
    final summaries = ref.watch(chatThreadSummariesProvider(t));
    final style = ChatStyle.watch(ref, context);
    // A jump window is older history: nobody types into it.
    final items = _items = [
      if (!inWindow) const ChatTypingItem(),
      ...chatListItems(messages, style.separatorGap),
    ];
    final list = MessageListView(
      thread: t,
      scroll: _scroll,
      items: items,
      style: style,
      users: users,
      summaries: summaries,
      showSenders: widget.showSenders,
      typingActive: !_away,
      extent: _extent,
      jump: _jump,
      header: MessageListHeader(
        reachedStart: reachedStart,
        isEmpty: messages.isEmpty,
        failed: loadFailed,
        onLoadOlder: loadOlder,
      ),
      onMetrics: _onScrollMetrics,
      onMouseDown: () => mouseDown = true,
      onMouseUp: _onMouseUp,
    );
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Stack(
      children: [
        list,
        // In the list it would scroll with it: over it, centred in the pane.
        if (messages.isEmpty && !loadFailed)
          Positioned.fill(
            child: loadingOlder
                ? const AppStateView.loading(compact: true)
                : AppStateView.empty(
                    compact: true,
                    icon: LucideIcons.messagesSquare300,
                    title: l.chatNoMessages,
                  ),
          ),
        Positioned(
          right: s.xl5,
          bottom: s.xl3,
          child: ScrollToLatestButton(
            // A jump window is never the latest, wherever it is scrolled.
            visible: _away || inWindow,
            unseen: _unseen,
            onPressed: _scrollToLatest,
          ),
        ),
      ],
    );
  }
}
