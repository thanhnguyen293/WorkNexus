import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/platform/open_external.dart';
import '../../../core/widgets/connection_text_field.dart';
import '../../../l10n/app_localizations.dart';
import 'connection_controllers.dart';
import 'widgets/connection_dialog_frame.dart';
import 'widgets/generate_token_link.dart';
import 'widgets/workspace_picker.dart';

/// Modal form for connecting a GitHub account with a Personal Access Token.
/// The token is stored in the OS keychain, never in the DB. Works with both
/// github.com and GitHub Enterprise Server (any base URL).
class GitHubConnectionDialog extends ConsumerStatefulWidget {
  const GitHubConnectionDialog({super.key, this.onProviderChanged});

  /// Shows the provider picker, switching to another provider's form.
  final ValueChanged<ProviderType>? onProviderChanged;

  @override
  ConsumerState<GitHubConnectionDialog> createState() =>
      _GitHubConnectionDialogState();
}

class _GitHubConnectionDialogState
    extends ConsumerState<GitHubConnectionDialog> {
  static const _kNewWorkspace = '__new__';

  final _baseUrl = TextEditingController(text: 'https://github.com');
  final _token = TextEditingController();
  final _newWorkspace = TextEditingController();
  String? _workspaceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(addConnectionControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _token.dispose();
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
      provider: ProviderType.github,
      title: l.connectGitHub,
      subtitle: l.githubConnectionSubtitle,
      fields: [
        ConnectionTextField(
          label: l.serverUrl,
          controller: _baseUrl,
          hint: l.githubServerHint,
          onSubmitted: submit,
        ),
        ConnectionTextField(
          label: l.personalAccessToken,
          controller: _token,
          hint: l.githubTokenHint,
          obscure: true,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: submit,
          trailing: GenerateTokenLink(onTap: _openTokenPage),
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
      onProviderChanged: widget.onProviderChanged,
    );
  }

  void _connect(AppL10n l, {required bool noWorkspace}) => ref
      .read(addConnectionControllerProvider.notifier)
      .connectGitHub(
        baseUrl: _baseUrl.text,
        token: _token.text,
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
    if (_token.text.trim().isEmpty) return false;
    if (noWorkspace) return true;
    if (_workspaceId == null) return false;
    if (_workspaceId == _kNewWorkspace) {
      return _newWorkspace.text.trim().isNotEmpty;
    }
    return true;
  }

  /// Opens GitHub's "new personal access token" page (classic, with the `repo` +
  /// `read:org` scopes pre-selected) for the entered server, in the default
  /// browser — so the user can create a token without hunting through settings.
  Future<void> _openTokenPage() async {
    final base = _tokenSettingsBase(_baseUrl.text);
    final url =
        '$base/settings/tokens/new?scopes=repo,read:org&description=WorkNexus';
    await openExternally(url);
  }

  /// The web origin hosting the token settings page, derived from the entered
  /// base URL: github.com / api.github.com → github.com; a GitHub Enterprise
  /// host stays as-is (its settings live on the same host), with any `/api/v3`
  /// suffix stripped.
  String _tokenSettingsBase(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return 'https://github.com';
    if (!u.startsWith('http')) u = 'https://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('/api/v3')) u = u.substring(0, u.length - '/api/v3'.length);
    final host = Uri.tryParse(u)?.host.toLowerCase();
    if (host == 'api.github.com') return 'https://github.com';
    return u;
  }
}
