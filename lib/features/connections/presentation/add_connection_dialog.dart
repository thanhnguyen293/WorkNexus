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
import 'connection_controllers.dart';

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
    final c = context.colors;
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
                  const ProviderBadge(ProviderType.zentao, big: true),
                  SizedBox(width: context.spacing.lg),
                  Text(
                    'Connect ZenTao',
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                'Enter your ZenTao server URL and login. Your password is stored '
                'in the macOS Keychain — never in the local database.',
                style: context.typography.paragraphSm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: context.spacing.xl3),
              _field(
                context,
                'Server URL',
                _baseUrl,
                hint: 'https://host:port/zentao (include the subpath)',
              ),
              SizedBox(height: context.spacing.lg),
              _field(
                context,
                'Account (username)',
                _username,
                hint: 'your-username',
              ),
              SizedBox(height: context.spacing.lg),
              _field(context, 'Password', _password, obscure: true),
              SizedBox(height: context.spacing.xl),
              _WorkspacePicker(
                workspaces: workspaces,
                value: _workspaceId,
                newValue: _kNewWorkspace,
                onChanged: (v) => setState(() => _workspaceId = v),
              ),
              if (_workspaceId == _kNewWorkspace) ...[
                SizedBox(height: context.spacing.lg),
                _field(
                  context,
                  'New workspace name',
                  _newWorkspace,
                  hint: 'e.g. Company C',
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
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: context.spacing.md),
                  AppButton.filled(
                    isLoading: state.busy,
                    onPressed: _canConnect(state)
                        ? () => ref
                              .read(addConnectionControllerProvider.notifier)
                              .connectZenTao(
                                baseUrl: _baseUrl.text,
                                username: _username.text,
                                password: _password.text,
                                workspaceId: _workspaceId == _kNewWorkspace
                                    ? null
                                    : _workspaceId,
                                newWorkspaceName: _workspaceId == _kNewWorkspace
                                    ? _newWorkspace.text
                                    : null,
                              )
                        : null,
                    child: const Text('Connect & sync'),
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
    if (_workspaceId == _kNewWorkspace) {
      return _newWorkspace.text.trim().isNotEmpty;
    }
    return true;
  }

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    ValueChanged<String>? onChanged,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: context.typography.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surfaceSubtle,
            hintText: hint,
            hintStyle: context.typography.body.copyWith(color: c.textTertiary),
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.lg,
              vertical: context.spacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspacePicker extends StatelessWidget {
  const _WorkspacePicker({
    required this.workspaces,
    required this.value,
    required this.newValue,
    required this.onChanged,
  });
  final List<dynamic> workspaces;
  final String? value;
  final String newValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workspace',
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: c.surfaceSubtle,
              style: context.typography.body.copyWith(color: c.textPrimary),
              items: [
                for (final w in workspaces)
                  DropdownMenuItem<String>(
                    value: w.id as String,
                    child: Text(
                      w.isPersonal == true ? 'Personal' : w.name as String,
                    ),
                  ),
                DropdownMenuItem<String>(
                  value: newValue,
                  child: Text(
                    '➕ New workspace…',
                    style: context.typography.body.copyWith(color: c.accent),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
