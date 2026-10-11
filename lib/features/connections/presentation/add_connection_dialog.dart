import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/widgets/connection_text_field.dart';
import '../../../l10n/app_localizations.dart';
import 'connection_controllers.dart';
import 'widgets/connection_dialog_frame.dart';
import 'widgets/workspace_picker.dart';

/// Modal form for connecting a ZenTao account. The user types their own
/// credentials; the password is stored in the OS keychain, never in the DB.
class AddConnectionDialog extends ConsumerStatefulWidget {
  const AddConnectionDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog(context: context, builder: (_) => const AddConnectionDialog());

  @override
  ConsumerState<AddConnectionDialog> createState() =>
      _AddConnectionDialogState();
}

class _AddConnectionDialogState extends ConsumerState<AddConnectionDialog> {
  static const _kNewWorkspace = '__new__';

  final _baseUrl = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _newWorkspace = TextEditingController();
  String? _workspaceId;

  @override
  void initState() {
    super.initState();
    // Reset after the first frame — modifying a provider during initState/build
    // is disallowed by Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(addConnectionControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    _newWorkspace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final workspaces = ref.watch(lookupsProvider).workspaces.values.toList();
    _workspaceId ??= initialWorkspaceId(workspaces);
    final noWorkspace = workspaces.isEmpty;
    final state = ref.watch(addConnectionControllerProvider);

    ref.listen(addConnectionControllerProvider, (_, s) {
      if (s.done && context.mounted) Navigator.of(context).pop();
    });

    final connect = _canConnect(state, noWorkspace: noWorkspace)
        ? () => _connect(l, noWorkspace: noWorkspace)
        : null;
    void submit(String _) => connect?.call();

    return ConnectionDialogFrame(
      provider: ProviderType.zentao,
      title: l.connectZenTao,
      subtitle: l.zentaoConnectionSubtitle,
      fields: [
        ConnectionTextField(
          label: l.serverUrl,
          controller: _baseUrl,
          hint: l.zentaoServerHint,
          autofocus: true,
          onSubmitted: submit,
        ),
        ConnectionTextField(
          label: l.connectionsUsername,
          controller: _username,
          hint: l.connectionsUsernameHint,
          onSubmitted: submit,
        ),
        ConnectionTextField(
          label: l.connectionsPassword,
          controller: _password,
          obscure: true,
          onSubmitted: submit,
        ),
      ],
      workspaces: workspaces,
      workspaceId: _workspaceId,
      newWorkspaceValue: _kNewWorkspace,
      newWorkspace: _newWorkspace,
      onWorkspaceChanged: (v) => setState(() => _workspaceId = v),
      onNewWorkspaceChanged: () => setState(() {}),
      busy: state.busy,
      error: state.error,
      onConnect: connect,
    );
  }

  void _connect(AppL10n l, {required bool noWorkspace}) => ref
      .read(addConnectionControllerProvider.notifier)
      .connectZenTao(
        baseUrl: _baseUrl.text,
        username: _username.text,
        password: _password.text,
        workspaceId: noWorkspace || _workspaceId == _kNewWorkspace
            ? null
            : _workspaceId,
        newWorkspaceName: noWorkspace
            ? l.defaultWorkspaceName
            : _workspaceId == _kNewWorkspace
            ? _newWorkspace.text
            : null,
      );

  bool _canConnect(AddConnectionState state, {required bool noWorkspace}) {
    if (state.busy) return false;
    if (noWorkspace) return true;
    if (_workspaceId == null) return false;
    if (_workspaceId == _kNewWorkspace) {
      return _newWorkspace.text.trim().isNotEmpty;
    }
    return true;
  }
}
