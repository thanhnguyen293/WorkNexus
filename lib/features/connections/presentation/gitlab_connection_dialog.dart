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

/// Modal form for connecting a GitLab account with a Personal Access Token.
/// The token is stored in the OS keychain, never in the DB. Works with both
/// gitlab.com and self-hosted instances (any base URL).
class GitLabConnectionDialog extends ConsumerStatefulWidget {
  const GitLabConnectionDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
    context: context,
    builder: (_) => const GitLabConnectionDialog(),
  );

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
                  const ProviderBadge(ProviderType.gitlab, big: true),
                  SizedBox(width: context.spacing.lg),
                  Text(
                    l.connectGitLab,
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                l.gitlabConnectionSubtitle,
                style: context.typography.paragraphSm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: context.spacing.xl3),
              ConnectionTextField(
                label: l.serverUrl,
                controller: _baseUrl,
                hint: l.gitlabServerHint,
              ),
              SizedBox(height: context.spacing.lg),
              ConnectionTextField(
                label: l.personalAccessToken,
                controller: _token,
                hint: l.gitlabTokenHint,
                obscure: true,
                onChanged: (_) => setState(() {}),
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
                              .connectGitLab(
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
}
