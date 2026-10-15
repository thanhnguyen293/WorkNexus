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

/// Modal form for connecting a GitLab account with a Personal Access Token.
/// The token is stored in the OS keychain, never in the DB. Works with both
/// gitlab.com and self-hosted instances (any base URL).
class GitLabConnectionDialog extends ConsumerStatefulWidget {
  const GitLabConnectionDialog({super.key, this.onProviderChanged});

  /// Shows the provider picker, switching to another provider's form.
  final ValueChanged<ProviderType>? onProviderChanged;

  @override
  ConsumerState<GitLabConnectionDialog> createState() =>
      _GitLabConnectionDialogState();
}

class _GitLabConnectionDialogState
    extends ConsumerState<GitLabConnectionDialog> {
  static const _kNewWorkspace = '__new__';

  final _baseUrl = TextEditingController(text: 'https://gitlab.com');
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
      provider: ProviderType.gitlab,
      title: l.connectGitLab,
      subtitle: l.gitlabConnectionSubtitle,
      fields: [
        ConnectionTextField(
          label: l.serverUrl,
          controller: _baseUrl,
          hint: l.gitlabServerHint,
          onSubmitted: submit,
        ),
        ConnectionTextField(
          label: l.personalAccessToken,
          controller: _token,
          hint: l.gitlabTokenHint,
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
      .connectGitLab(
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

  /// Opens GitLab's "new personal access token" page (with the `api` scope and a
  /// token name pre-filled) for the entered server, in the default browser.
  ///
  /// GitLab moved this page's route across versions and there is no single path
  /// that resolves on every version:
  ///   • pre-16.x       → only `/-/profile/personal_access_tokens`
  ///   • 16.x           → `/-/user_settings/…` (canonical); `/-/profile/…` redirects
  ///   • 17.x and later → only `/-/user_settings/personal_access_tokens`
  /// gitlab.com (SaaS) always runs the latest, so it gets the modern path; a
  /// self-hosted host may be older, so it gets the legacy `/-/profile/…` path,
  /// which GitLab 16.x transparently redirects to the modern one.
  Future<void> _openTokenPage() async {
    final base = _tokenSettingsBase(_baseUrl.text);
    final isSaaS = Uri.tryParse(base)?.host == 'gitlab.com';
    final path = isSaaS
        ? '/-/user_settings/personal_access_tokens'
        : '/-/profile/personal_access_tokens';
    final url = '$base$path?name=WorkNexus&scopes=api';
    await openExternally(url);
  }

  /// The origin hosting the token settings page, derived from the entered base
  /// URL (GitLab's web + API share a host): trims a trailing slash and any
  /// pasted `/api/v4`; empty → gitlab.com.
  String _tokenSettingsBase(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return 'https://gitlab.com';
    if (!u.startsWith('http')) u = 'https://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('/api/v4')) u = u.substring(0, u.length - '/api/v4'.length);
    return u;
  }
}
