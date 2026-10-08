import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import 'opencode_key_controller.dart';
import 'widgets/connection_text_field.dart';

/// Modal form for adding or replacing the API key OpenCode uses for one
/// provider. Passing [providerId] pins the provider and turns this into a
/// "change the key" form; leaving it null lets the user name a new one.
class OpenCodeKeyDialog extends ConsumerStatefulWidget {
  const OpenCodeKeyDialog({super.key, this.providerId});

  final String? providerId;

  static Future<void> show(BuildContext context, {String? providerId}) =>
      showDialog(
        context: context,
        builder: (_) => OpenCodeKeyDialog(providerId: providerId),
      );

  @override
  ConsumerState<OpenCodeKeyDialog> createState() => _OpenCodeKeyDialogState();
}

class _OpenCodeKeyDialogState extends ConsumerState<OpenCodeKeyDialog> {
  late final TextEditingController _provider = TextEditingController(
    text: widget.providerId ?? '',
  );
  final TextEditingController _key = TextEditingController();
  bool _obscure = true;

  bool get _isEditing => widget.providerId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(openCodeKeyControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final state = ref.watch(openCodeKeyControllerProvider);

    ref.listen(openCodeKeyControllerProvider, (_, s) {
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
              Text(
                _isEditing
                    ? l.openCodeChangeKeyTitle(widget.providerId!)
                    : l.openCodeAddKeyTitle,
                style: context.typography.title.copyWith(color: c.textPrimary),
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                l.openCodeKeyDialogSubtitle,
                style: context.typography.paragraphSm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: context.spacing.xl3),
              if (!_isEditing) ...[
                ConnectionTextField(
                  label: l.openCodeProviderLabel,
                  controller: _provider,
                  hint: l.openCodeProviderHint,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: context.spacing.lg),
              ],
              ConnectionTextField(
                label: l.openCodeApiKeyLabel,
                controller: _key,
                hint: l.openCodeApiKeyHint,
                obscure: _obscure,
                onChanged: (_) => setState(() {}),
                trailing: _RevealToggle(
                  obscured: _obscure,
                  onTap: () => setState(() => _obscure = !_obscure),
                ),
              ),
              if (state.error != null) ...[
                SizedBox(height: context.spacing.xl),
                _ErrorBox(message: state.error!),
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
                    onPressed: _canSave(state) ? _save : null,
                    child: Text(l.openCodeSaveKey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSave(OpenCodeKeyState state) =>
      !state.busy &&
      _key.text.trim().isNotEmpty &&
      _provider.text.trim().isNotEmpty;

  void _save() => ref
      .read(openCodeKeyControllerProvider.notifier)
      .saveKey(providerId: _provider.text, key: _key.text);
}

/// Show/hide switch for the key field, sitting in the field's label row.
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AppButton.text(
      size: AppButtonSize.small,
      onPressed: onTap,
      child: Text(obscured ? l.openCodeShowKey : l.openCodeHideKey),
    );
  }
}

/// Tinted panel carrying a [Failure] message from the controller.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.lg),
      decoration: BoxDecoration(
        color: c.mixT(c.error, 0.10),
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.mixT(c.error, 0.35)),
      ),
      child: Text(
        message,
        style: context.typography.bodySm.copyWith(color: c.textPrimary),
      ),
    );
  }
}
