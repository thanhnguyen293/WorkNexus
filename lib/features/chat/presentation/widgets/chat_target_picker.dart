import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'forward_chat_row.dart';

/// Search plus a list of the chats of [accountId] the user may post in, each
/// picked or not — what forwarding and sending something into chat pick
/// from. Fills the height it is given.
class ChatTargetPicker extends ConsumerStatefulWidget {
  const ChatTargetPicker({
    super.key,
    required this.accountId,
    required this.selected,
    required this.onToggle,
    this.autofocus = true,
  });

  final String accountId;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final bool autofocus;

  @override
  ConsumerState<ChatTargetPicker> createState() => _ChatTargetPickerState();
}

class _ChatTargetPickerState extends ConsumerState<ChatTargetPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final users =
        ref.watch(chatUsersProvider(widget.accountId)).value ??
        const <int, ChatUser>{};
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final e in _targets(context, users))
        if (query.isEmpty || e.title.toLowerCase().contains(query)) e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _search,
          autofocus: widget.autofocus,
          hint: l.chatSearch,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: context.spacing.md),
        Expanded(
          child: shown.isEmpty
              ? AppStateView.empty(
                  compact: true,
                  icon: LucideIcons.messageSquareOff300,
                  title: l.chatNoMatches,
                )
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final e = shown[i];
                    return ForwardChatRow(
                      key: ValueKey(e.chat.gid),
                      title: e.title,
                      avatar: chatAvatarStyle(e.chat, users),
                      picked: widget.selected.contains(e.chat.gid),
                      onTap: () => widget.onToggle(e.chat.gid),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The chats one can send to: listed (not hidden or archived) and open to
  /// the user's posts, in the chat list's order.
  List<({ChatConversation chat, String title})> _targets(
    BuildContext context,
    Map<int, ChatUser> users,
  ) {
    final controller = ref.watch(chatControllerProvider);
    final self = ref.watch(chatSelfUserIdProvider(widget.accountId)).value;
    return [
      for (final chat
          in ref.watch(chatConversationsProvider(widget.accountId)).value ??
              const <ChatConversation>[])
        if (!chat.hidden &&
            !chat.archived &&
            controller.canSend(
              chat,
              selfUserId: self,
              selfAccount: users[self]?.account,
            ))
          (chat: chat, title: chatTitle(context, chat, users)),
    ];
  }
}
