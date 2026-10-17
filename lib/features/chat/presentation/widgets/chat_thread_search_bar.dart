import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_search_providers.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';
import 'chat_search_status.dart';

/// Compact floating/docked in-thread search bar for chatting.
/// Allows stepping through matching messages with Prev/Next buttons
/// and jumping to the message in timeline.
class ChatThreadSearchBar extends ConsumerStatefulWidget {
  const ChatThreadSearchBar({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  ConsumerState<ChatThreadSearchBar> createState() =>
      _ChatThreadSearchBarState();
}

class _ChatThreadSearchBarState extends ConsumerState<ChatThreadSearchBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(chatThreadSearchQueryProvider(widget.thread));
    _controller = TextEditingController(text: initialQuery);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    ref.read(chatThreadSearchQueryProvider(widget.thread).notifier).state =
        query;
    ref
            .read(chatThreadSearchActiveIndexProvider(widget.thread).notifier)
            .state =
        -1;
  }

  /// Steps [delta] matches older (positive) or newer, wrapping around.
  /// Stepping past the oldest match loaded asks for the next page first,
  /// when more are stored, rather than wrapping back to the newest.
  Future<void> _stepMatch(ChatSearchResults results, int delta) async {
    var matches = results.messages;
    if (matches.isEmpty) return;
    final currentIndex = ref.read(
      chatThreadSearchActiveIndexProvider(widget.thread),
    );
    final int nextIndex;
    if (currentIndex < 0 || currentIndex >= matches.length) {
      // Nothing visited yet (or the matches shrank): start at an end.
      nextIndex = delta > 0 ? 0 : matches.length - 1;
    } else if (currentIndex + delta >= matches.length && results.hasMore) {
      nextIndex = currentIndex + delta;
      ref.read(chatThreadSearchLimitProvider(widget.thread).notifier).state +=
          chatSearchPageSize;
      try {
        matches = (await ref.read(
          chatThreadSearchMatchesProvider(widget.thread).future,
        )).messages;
      } on Exception {
        return; // The bar shows the failure.
      }
      if (!mounted || nextIndex >= matches.length) return;
    } else {
      nextIndex = (currentIndex + delta + matches.length) % matches.length;
    }
    ref
            .read(chatThreadSearchActiveIndexProvider(widget.thread).notifier)
            .state =
        nextIndex;

    if (matches[nextIndex].serverId case final serverId?) {
      jumpToChatMessage(ref, widget.thread, serverId);
    }
    _focusNode.requestFocus();
  }

  void _close() {
    ref.read(chatThreadSearchIsOpenProvider(widget.thread).notifier).state =
        false;
    ref.read(chatThreadSearchQueryProvider(widget.thread).notifier).state = '';
    ref
            .read(chatThreadSearchActiveIndexProvider(widget.thread).notifier)
            .state =
        -1;
  }

  void _openGlobalSearch(BuildContext context) {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      ref
              .read(
                chatGlobalSearchQueryProvider(widget.thread.accountId).notifier,
              )
              .state =
          query;
    }
    toggleChatSidePanel(
      ref,
      widget.thread,
      ChatSidePanel.search,
      infoRoom: ChatLayoutScope.of(context).infoRoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final query = ref.watch(chatThreadSearchQueryProvider(widget.thread));
    // The global search panel writes the same query: keep the field in step.
    ref.listen(chatThreadSearchQueryProvider(widget.thread), (_, next) {
      if (_controller.text != next) _controller.text = next;
    });
    final matchesAsync = ref.watch(
      chatThreadSearchMatchesProvider(widget.thread),
    );
    // While the next page loads, the matches so far stay listed.
    final results = matchesAsync.value ?? (messages: const [], hasMore: false);
    final matches = results.messages;
    final activeIndex = ref.watch(
      chatThreadSearchActiveIndexProvider(widget.thread),
    );

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _close();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            final isShift = HardwareKeyboard.instance.isShiftPressed;
            _stepMatch(results, isShift ? -1 : 1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            bottom: BorderSide(
              color: c.border,
              width: context.borders.hairline,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.search300, size: 16, color: c.textSecondary),
            SizedBox(width: context.spacing.xs),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.none,
                onEditingComplete: () {},
                style: context.typography.body.copyWith(
                  fontSize: 13,
                  color: c.textPrimary,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: l.chatSearchMessages,
                  hintStyle: context.typography.body.copyWith(
                    fontSize: 13,
                    color: c.textTertiary,
                  ),
                ),
                onChanged: _onQueryChanged,
                onSubmitted: (_) {
                  final isShift = HardwareKeyboard.instance.isShiftPressed;
                  _stepMatch(results, isShift ? -1 : 1);
                },
              ),
            ),
            if (query.isNotEmpty) ...[
              if (matchesAsync.hasError)
                ChatSearchFailedLabel(message: l.chatSearchFailed)
              else if (matchesAsync.isLoading && !matchesAsync.hasValue)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
                  child: SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: c.accent,
                    ),
                  ),
                )
              else
                ChatSearchCounter(
                  count: matches.length,
                  hasMore: results.hasMore,
                  activeIndex: activeIndex,
                ),
              SizedBox(width: context.spacing.xxs),
              AppIconButton(
                icon: LucideIcons.chevronUp300,
                tooltip: l.chatPrevious,
                size: AppIconButtonSize.small,
                onPressed: matches.isNotEmpty
                    ? () => _stepMatch(results, -1)
                    : null,
              ),
              AppIconButton(
                icon: LucideIcons.chevronDown300,
                tooltip: l.chatNext,
                size: AppIconButtonSize.small,
                onPressed: matches.isNotEmpty
                    ? () => _stepMatch(results, 1)
                    : null,
              ),
              SizedBox(width: context.spacing.xxs),
              AppIconButton(
                icon: LucideIcons.folderSearch300,
                tooltip: l.chatSearchAllChats,
                size: AppIconButtonSize.small,
                onPressed: () => _openGlobalSearch(context),
              ),
            ],
            AppIconButton(
              icon: LucideIcons.x300,
              tooltip: l.chatCancel,
              size: AppIconButtonSize.small,
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }
}
