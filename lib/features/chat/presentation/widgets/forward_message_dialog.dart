import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';
import 'forward_chat_row.dart';

/// Picks one or more chats of the message's account and forwards the
/// message to them. Lists only chats the user may post in.
class ForwardMessageDialog extends ConsumerStatefulWidget {
  const ForwardMessageDialog({super.key, required this.message});

  final ChatMessage message;

  static Future<void> show(BuildContext context, ChatMessage message) =>
      showDialog<void>(
        context: context,
        builder: (_) => ForwardMessageDialog(message: message),
      );

  @override
  ConsumerState<ForwardMessageDialog> createState() =>
      _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends ConsumerState<ForwardMessageDialog> {
  final _search = TextEditingController();
  final _selected = <String>[];
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String chatGid) => setState(
    () => _selected.contains(chatGid)
        ? _selected.remove(chatGid)
        : _selected.add(chatGid),
  );

  Future<void> _forward() async {
    setState(() => _busy = true);
    final count = _selected.length;
    final result = await ref
        .read(chatControllerProvider)
        .forward(widget.message, toChatGids: List.of(_selected));
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        showChatSnack(context, AppL10n.of(context).chatForwarded(count));
      case Err(:final failure):
        setState(() => _busy = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final accountId = widget.message.accountId;
    final chats = _targets(context, accountId);
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final e in chats)
        if (query.isEmpty || e.title.toLowerCase().contains(query)) e,
    ];
    final users =
        ref.watch(chatUsersProvider(accountId)).value ??
        const <int, ChatUser>{};
    // A fixed height: searching must not make the dialog grow and shrink.
    final height = (MediaQuery.sizeOf(context).height * 0.8).clamp(
      320.0,
      600.0,
    );
    return AppDialogFrame(
      title: l.chatForwardTitle,
      leadingIcon: LucideIcons.forward300,
      maxWidth: context.sizes.dialogSm,
      maxHeight: height,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.chatCancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _busy,
          isDisabled: _selected.isEmpty,
          onPressed: _selected.isEmpty || _busy ? null : _forward,
          child: Text(
            _selected.length > 1
                ? l.chatForwardTo(_selected.length)
                : l.chatForward,
          ),
        ),
      ],
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                chatPreview(context, widget.message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: s.xl),
              AppSearchField(
                controller: _search,
                autofocus: true,
                hint: l.chatSearch,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: s.md),
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
                            picked: _selected.contains(e.chat.gid),
                            onTap: () => _toggle(e.chat.gid),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The chats one can forward to: listed (not hidden or archived) and open
  /// to the user's posts, in the chat list's order.
  List<({ChatConversation chat, String title})> _targets(
    BuildContext context,
    String accountId,
  ) {
    final controller = ref.watch(chatControllerProvider);
    final users =
        ref.watch(chatUsersProvider(accountId)).value ??
        const <int, ChatUser>{};
    final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
    return [
      for (final chat
          in ref.watch(chatConversationsProvider(accountId)).value ??
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
