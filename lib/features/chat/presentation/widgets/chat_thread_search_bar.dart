import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';

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

  void _stepMatch(List<ChatMessage> matches, int delta) {
    if (matches.isEmpty) return;
    final currentIndex = ref.read(
      chatThreadSearchActiveIndexProvider(widget.thread),
    );
    // Nothing visited yet (or the matches shrank): start at an end.
    final nextIndex = currentIndex < 0 || currentIndex >= matches.length
        ? (delta > 0 ? 0 : matches.length - 1)
        : (currentIndex + delta + matches.length) % matches.length;
    ref
            .read(chatThreadSearchActiveIndexProvider(widget.thread).notifier)
            .state =
        nextIndex;

    final targetMsg = matches[nextIndex];
    if (targetMsg.serverId != null) {
      jumpToChatMessage(ref, widget.thread, targetMsg.serverId!);
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
    final matches = matchesAsync.asData?.value ?? const <ChatMessage>[];
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
            _stepMatch(matches, isShift ? -1 : 1);
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
                  _stepMatch(matches, isShift ? -1 : 1);
                },
              ),
            ),
            if (query.isNotEmpty) ...[
              if (matchesAsync.isLoading)
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
                _MatchCounterBadge(
                  count: matches.length,
                  activeIndex: activeIndex,
                ),
              SizedBox(width: context.spacing.xxs),
              AppIconButton(
                icon: LucideIcons.chevronUp300,
                tooltip: l.chatPrevious,
                size: AppIconButtonSize.small,
                onPressed: matches.isNotEmpty
                    ? () => _stepMatch(matches, -1)
                    : null,
              ),
              AppIconButton(
                icon: LucideIcons.chevronDown300,
                tooltip: l.chatNext,
                size: AppIconButtonSize.small,
                onPressed: matches.isNotEmpty
                    ? () => _stepMatch(matches, 1)
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

class _MatchCounterBadge extends StatelessWidget {
  const _MatchCounterBadge({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final text = count == 0
        ? l.chatSearchNoMatches
        : l.chatSearchMatches(activeIndex.clamp(0, count - 1) + 1, count);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: count == 0 ? c.surfaceSubtle : c.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
      child: Text(
        text,
        style: context.typography.secondary.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: count == 0 ? c.textTertiary : c.accent,
        ),
      ),
    );
  }
}
