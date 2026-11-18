import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';
import 'new_chat_people.dart';

/// Picks people to add to a group, with the new-chat dialog's people picker
/// (its current members left out).
class ChatAddMembersDialog extends ConsumerStatefulWidget {
  const ChatAddMembersDialog({
    super.key,
    required this.thread,
    required this.chat,
    required this.members,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Set<int> members;

  static Future<void> show(
    BuildContext context, {
    required ChatThreadKey thread,
    required ChatConversation chat,
    required Set<int> members,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        ChatAddMembersDialog(thread: thread, chat: chat, members: members),
  );

  @override
  ConsumerState<ChatAddMembersDialog> createState() =>
      _ChatAddMembersDialogState();
}

class _ChatAddMembersDialogState extends ConsumerState<ChatAddMembersDialog> {
  final _search = TextEditingController();
  final _selected = <int>[];
  bool _busy = false;

  /// The directory load's outcome; null while it runs.
  Result<void>? _directory;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  /// Only users seen in chats are cached: load the whole directory.
  Future<void> _loadDirectory() async {
    if (_directory != null) setState(() => _directory = null);
    final result = await ref
        .read(chatControllerProvider)
        .refreshUsers(widget.thread.accountId);
    if (mounted) setState(() => _directory = result);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _add() async {
    if (_busy || _selected.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref
        .read(chatGroupControllerProvider)
        .addMembers(widget.chat, _selected);
    if (!mounted) return;
    switch (result) {
      case Ok():
        // Members are fetched on demand, not stored: ask again.
        ref
          ..invalidate(chatMembersProvider(widget.thread))
          ..invalidate(chatMemberCountProvider(widget.thread));
        showChatSnack(context, AppL10n.of(context).chatMembersAdded);
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() => _busy = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final usersAsync = ref.watch(chatUsersProvider(widget.thread.accountId));
    // A fixed height, so searching does not make the dialog jump.
    final height = (MediaQuery.sizeOf(context).height * 0.85).clamp(
      320.0,
      640.0,
    );
    return AppDialogFrame(
      title: l.chatAddMembers,
      maxWidth: context.sizes.dialogMd,
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
          onPressed: _selected.isEmpty ? null : _add,
          child: Text(l.chatAdd),
        ),
      ],
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl),
          child: NewChatPeople(
            accountId: widget.thread.accountId,
            search: _search,
            selected: _selected,
            onToggle: _toggle,
            excluded: widget.members,
            loading: usersAsync.isLoading || _directory == null,
            failed: usersAsync.hasError || _directory is Err,
            onRetry: _loadDirectory,
          ),
        ),
      ),
    );
  }
}
