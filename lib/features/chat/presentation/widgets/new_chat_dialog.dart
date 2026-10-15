import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
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

  /// The directory load's outcome; null while it runs.
  Result<void>? _directory;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  /// Only users seen in chats are cached: load the whole directory. Its
  /// outcome is kept so an empty list can say "failed" rather than spin.
  Future<void> _loadDirectory() async {
    if (_directory != null) setState(() => _directory = null);
    final result = await ref
        .read(chatControllerProvider)
        .refreshUsers(widget.accountId);
    if (mounted) setState(() => _directory = result);
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
        ref.read(appNavProvider.notifier).selectAccount(id);
        ref
            .read(appNavProvider.notifier)
            .selectSection(const SectionId('zentao.chat'));
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
    final usersAsync = ref.watch(chatUsersProvider(widget.accountId));
    final users = usersAsync.value ?? {};
    final group = _selected.length > 1;
    final canStart = _selected.isNotEmpty && !_busy;
    void start() {
      if (canStart) _start(users);
    }

    // A fixed height: switching tabs or searching changes how many people
    // are listed, which must not make the dialog grow and shrink.
    final height = (MediaQuery.sizeOf(context).height * 0.85).clamp(
      320.0,
      640.0,
    );
    return AppDialogFrame(
      title: l.chatNewChat,
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
          onPressed: canStart ? start : null,
          child: Text(group ? l.chatCreateGroup : l.chatSendMessage),
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
                l.chatNewChatHint,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: s.xl),
              if (group) ...[
                TextField(
                  controller: _name,
                  onSubmitted: (_) => start(),
                  style: context.typography.body.copyWith(color: c.textPrimary),
                  decoration: appInputDecoration(
                    context,
                    hint: '${l.chatGroupName} · ${_defaultName(users)}',
                    prefixIcon: LucideIcons.users300,
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
                  loading: usersAsync.isLoading || _directory == null,
                  failed: usersAsync.hasError || _directory is Err,
                  onRetry: _loadDirectory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
