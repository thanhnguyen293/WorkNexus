import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../l10n/app_localizations.dart';
import 'connection_controllers.dart';
import 'widgets/connection_text_field.dart';
import 'widgets/workspace_picker.dart';

/// Modal form for connecting a GitHub account with a Personal Access Token.
/// The token is stored in the OS keychain, never in the DB. Works with both
/// github.com and GitHub Enterprise Server (any base URL).
class GitHubConnectionDialog extends ConsumerStatefulWidget {
  const GitHubConnectionDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
    context: context,
    builder: (_) => const GitHubConnectionDialog(),
  );

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
    final c = context.colors;
    final l = AppL10n.of(context);
    final workspaces = ref.watch(lookupsProvider).workspaces.values.toList();
    _workspaceId ??= workspaces.isEmpty ? null : workspaces.first.id;
    final state = ref.watch(addConnectionControllerProvider);

    ref.listen(addConnectionControllerProvider, (_, s) {
      if (s.done && context.mounted) Navigator.of(context).pop();
    });

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ProviderBadge(ProviderType.github, big: true),
                  SizedBox(width: context.spacing.lg),
                  Text(
                    l.connectGitHub,
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                l.githubConnectionSubtitle,
                style: context.typography.paragraphSm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: context.spacing.xl3),
              ConnectionTextField(
                label: l.serverUrl,
                controller: _baseUrl,
                hint: l.githubServerHint,
              ),
              SizedBox(height: context.spacing.lg),
              ConnectionTextField(
                label: l.personalAccessToken,
                controller: _token,
                hint: l.githubTokenHint,
                obscure: true,
                onChanged: (_) => setState(() {}),
                trailing: _GenerateTokenLink(onTap: _openTokenPage),
              ),
              SizedBox(height: context.spacing.xl),
              WorkspacePicker(
                workspaces: workspaces,
                value: _workspaceId,
                newValue: _kNewWorkspace,
                onChanged: (v) => setState(() => _workspaceId = v),
              ),
              if (_workspaceId == _kNewWorkspace) ...[
                SizedBox(height: context.spacing.lg),
                ConnectionTextField(
                  label: l.newWorkspaceName,
                  controller: _newWorkspace,
                  hint: l.newWorkspaceHint,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (state.error != null) ...[
                SizedBox(height: context.spacing.xl),
                Container(
                  padding: EdgeInsets.all(context.spacing.lg),
                  decoration: BoxDecoration(
                    color: c.mixT(c.error, 0.10),
                    borderRadius: BorderRadius.circular(context.radii.md),
                    border: Border.all(color: c.mixT(c.error, 0.35)),
                  ),
                  child: Text(
                    state.error!,
                    style: context.typography.bodySm.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
              SizedBox(height: context.spacing.xl3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.textNeutral(
                    onPressed: state.busy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l.cancel),
                  ),
                  SizedBox(width: context.spacing.md),
                  AppButton.filled(
                    isLoading: state.busy,
                    onPressed: _canConnect(state)
                        ? () => ref
                              .read(addConnectionControllerProvider.notifier)
                              .connectGitHub(
                                baseUrl: _baseUrl.text,
                                token: _token.text,
                                workspaceId: _workspaceId == _kNewWorkspace
                                    ? null
                                    : _workspaceId,
                                newWorkspaceName: _workspaceId == _kNewWorkspace
                                    ? _newWorkspace.text
                                    : null,
                              )
                        : null,
                    child: Text(l.connectAndSync),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canConnect(AddConnectionState state) {
    if (state.busy || _workspaceId == null) return false;
    if (_token.text.trim().isEmpty) return false;
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
    try {
      await Process.run('open', [url]);
    } catch (_) {
      // best-effort; nothing to surface if the platform lacks `open`.
    }
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

/// A subtle "Generate token" link shown beside the PAT field's label; opens the
/// provider's token-creation page in the browser.
class _GenerateTokenLink extends StatelessWidget {
  const _GenerateTokenLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.xs,
          vertical: context.spacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, size: 12, color: c.accent),
            SizedBox(width: context.spacing.xxs),
            Text(
              l.githubGenerateToken,
              style: context.typography.captionStrong.copyWith(color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}
