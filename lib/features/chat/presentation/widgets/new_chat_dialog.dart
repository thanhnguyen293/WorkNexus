import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_field_decoration.dart';
import 'chat_snack.dart';
import 'new_chat_people.dart';

/// Starts a chat: pick one person for a direct chat (opened, or created on
/// the server) or several for a group, which then needs a name.
class NewChatDialog extends ConsumerStatefulWidget {
  const NewChatDialog({super.key, required this.accountId});

  final String accountId;

  static Future<void> show(BuildContext context, String accountId) =>
      showDialog<void>(
        context: context,
        builder: (_) => NewChatDialog(accountId: accountId),
      );

  @override
  ConsumerState<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends ConsumerState<NewChatDialog> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _selected = <int>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Only users seen in chats are cached: load the whole directory.
    ref.read(chatControllerProvider).refreshUsers(widget.accountId);
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _start(Map<int, ChatUser> users) async {
    setState(() => _busy = true);
    final controller = ref.read(chatControllerProvider);
    final id = widget.accountId;
    final result = _selected.length == 1
        ? await controller.openDirectChat(id, _selected.single)
        : await controller.createGroupChat(
            id,
            name: _name.text.trim().isEmpty ? _defaultName(users) : _name.text,
            memberIds: _selected,
          );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        showChatView(ref);
        ref.read(pickedChatAccountProvider.notifier).state = id;
        ref.read(selectedChatGidProvider(id).notifier).state = value;
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() => _busy = false);
        showChatFailure(context, failure);
    }
  }

  /// "An, Bình, Chi" when the user leaves the group name empty.
  String _defaultName(Map<int, ChatUser> users) => _selected
      .take(4)
      .map((id) {
        final u = users[id];
        return u == null || u.realname.isEmpty
            ? (u?.account ?? '#$id')
            : u.realname;
      })
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final users = ref.watch(chatUsersProvider(widget.accountId)).value ?? {};
    final group = _selected.length > 1;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      // A fixed size: switching tabs or searching changes how many people
      // are listed, which must not make the dialog grow and shrink.
      child: SizedBox(
        width: 440,
        height: (MediaQuery.sizeOf(context).height * 0.85).clamp(320, 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xl5, s.xl3, s.xl5, s.xl5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.chatNewChat,
                      style: context.typography.titleLg.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.chatCancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x300, color: c.textSecondary),
                  ),
                ],
              ),
              SizedBox(height: s.xs),
              Text(
                l.chatNewChatHint,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: s.xl3),
              if (group) ...[
                TextField(
                  controller: _name,
                  style: context.typography.body.copyWith(color: c.textPrimary),
                  decoration: chatFieldDecoration(
                    context,
                    hint: '${l.chatGroupName} · ${_defaultName(users)}',
                    icon: LucideIcons.users300,
                  ),
                ),
                SizedBox(height: s.xl),
              ],
              Expanded(
                child: NewChatPeople(
                  accountId: widget.accountId,
                  search: _search,
                  selected: _selected,
                  onToggle: _toggle,
                ),
              ),
              SizedBox(height: s.xl3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.textNeutral(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.chatCancel),
                  ),
                  SizedBox(width: s.md),
                  AppButton.filled(
                    isLoading: _busy,
                    isDisabled: _selected.isEmpty,
                    onPressed: _selected.isEmpty || _busy
                        ? null
                        : () => _start(users),
                    child: Text(group ? l.chatCreateGroup : l.chatSendMessage),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
