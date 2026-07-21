import 'package:flutter/material.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'metadata_editor_parts.dart';
import 'provider_user_avatar.dart';

typedef UserOptionsLoader = Future<Result<List<ProviderUser>>> Function();
typedef UsersSaver = Future<Result<void>> Function(List<String> accounts);

class UserPickerEditor extends StatefulWidget {
  const UserPickerEditor({
    super.key,
    required this.currentUsers,
    required this.multiple,
    required this.loadUsers,
    required this.onSave,
    required this.onClose,
    required this.avatarLoader,
  });

  final List<String> currentUsers;
  final bool multiple;
  final UserOptionsLoader loadUsers;
  final UsersSaver onSave;
  final VoidCallback onClose;
  final AvatarLoader avatarLoader;

  @override
  State<UserPickerEditor> createState() => _UserPickerEditorState();
}

class _UserPickerEditorState extends State<UserPickerEditor> {
  late final Future<Result<List<ProviderUser>>> _users;
  final _search = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';
  String? _error;
  bool _initialized = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _users = widget.loadUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _initializeSelection(List<ProviderUser> users) {
    if (_initialized) return;
    _initialized = true;
    final current = widget.currentUsers.toSet();
    var changed = false;
    for (final user in users) {
      if (current.contains(user.account) ||
          current.contains(user.displayName)) {
        changed = _selected.add(user.account) || changed;
      }
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  List<ProviderUser> _visible(List<ProviderUser> users) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users
        .where(
          (user) =>
              user.displayName.toLowerCase().contains(query) ||
              user.account.toLowerCase().contains(query),
        )
        .toList();
  }

  void _toggle(ProviderUser user) {
    setState(() {
      _error = null;
      if (widget.multiple) {
        if (!_selected.remove(user.account)) _selected.add(user.account);
      } else {
        _selected
          ..clear()
          ..add(user.account);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSave(_selected.toList());
    if (!mounted) return;
    if (result case Err<void>(:final failure)) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
      return;
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorSearchField(
          controller: _search,
          hint: l.searchUsers,
          onChanged: (value) => setState(() => _query = value),
        ),
        Flexible(
          child: FutureBuilder<Result<List<ProviderUser>>>(
            future: _users,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (result case Err<List<ProviderUser>>(:final failure)) {
                return EditorMessage(
                  message: failure.message,
                  isError: true,
                );
              }
              final users = (result as Ok<List<ProviderUser>>).value;
              _initializeSelection(users);
              final visible = _visible(users);
              return _UserOptions(
                users: visible,
                selected: _selected,
                multiple: widget.multiple,
                avatarLoader: widget.avatarLoader,
                onClear: () => setState(_selected.clear),
                onToggle: _toggle,
              );
            },
          ),
        ),
        EditorFooter(
          busy: _busy,
          error: _error,
          onSave: !widget.multiple && _selected.isEmpty ? null : _save,
        ),
      ],
    );
  }
}

class _UserOptions extends StatelessWidget {
  const _UserOptions({
    required this.users,
    required this.selected,
    required this.multiple,
    required this.avatarLoader,
    required this.onClear,
    required this.onToggle,
  });

  final List<ProviderUser> users;
  final Set<String> selected;
  final bool multiple;
  final AvatarLoader avatarLoader;
  final VoidCallback onClear;
  final ValueChanged<ProviderUser> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    if (users.isEmpty && !multiple) {
      return EditorMessage(message: l.noMatchingUsers);
    }
    return ListView(
      padding: EdgeInsets.only(bottom: context.spacing.xs),
      shrinkWrap: true,
      children: [
        if (multiple) ...[
          EditorOptionTile(
            title: l.unassigned,
            selected: selected.isEmpty,
            onTap: onClear,
          ),
          Divider(height: 1, color: context.colors.border),
        ],
        if (users.isEmpty) EditorMessage(message: l.noMatchingUsers),
        for (final user in users)
          EditorOptionTile(
            title: user.displayName,
            subtitle: '@${user.account}',
            selected: selected.contains(user.account),
            leading: ProviderAvatarImage(
              name: user.displayName,
              avatarUrl: user.avatarUrl,
              imageLoader: avatarLoader,
            ),
            onTap: () => onToggle(user),
          ),
      ],
    );
  }
}
