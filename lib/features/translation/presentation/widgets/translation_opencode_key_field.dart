import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/opencode_provider_auth.dart';
import '../../domain/value_objects/opencode_key_links.dart';
import '../opencode_key_providers.dart';

/// The API key OpenCode translates with, for the provider of the chosen model
/// (`opencode/…` → `opencode`). It is written to OpenCode's own credential
/// store, so it is the key the CLI uses.
class TranslationOpenCodeKeyField extends ConsumerStatefulWidget {
  const TranslationOpenCodeKeyField({super.key});

  @override
  ConsumerState<TranslationOpenCodeKeyField> createState() =>
      _TranslationOpenCodeKeyFieldState();
}

class _TranslationOpenCodeKeyFieldState
    extends ConsumerState<TranslationOpenCodeKeyField> {
  final _key = TextEditingController();
  var _obscure = true;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save(String providerId) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(openCodeKeyControllerProvider.notifier)
        .save(providerId: providerId, key: _key.text);
    if (result.isOk) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.translationOpenCodeKeySaveDone(providerId))),
      );
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.isOk) {
        _key.clear();
      } else {
        _error = l.translationApiSaveFailed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final providerId = openCodeProviderOf(
      ref.watch(appSettingsProvider.select((s) => s.translationModel)),
    );
    final auth = ref.watch(openCodeProviderAuthProvider(providerId));
    final status = switch (auth) {
      AsyncData(:final value) => _statusOf(l, value.valueOrNull),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConnectionTextField(
          label: l.translationOpenCodeKey(providerId),
          controller: _key,
          obscure: _obscure,
          onChanged: (_) => setState(() {}),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => openExternally(openCodeKeyUrl(providerId)),
                child: Text(l.translationApiGetKey),
              ),
              TextButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                child: Text(_obscure ? l.openCodeShowKey : l.openCodeHideKey),
              ),
            ],
          ),
        ),
        if (status != null) ...[
          SizedBox(height: context.spacing.xs),
          AppInlineNote(text: status),
        ],
        if (_error != null) ...[
          SizedBox(height: context.spacing.md),
          AppInlineNote(text: _error!, isError: true),
        ],
        SizedBox(height: context.spacing.lg),
        AppButton.filled(
          isLoading: _saving,
          onPressed: !_saving && _key.text.trim().isNotEmpty
              ? () => _save(providerId)
              : null,
          child: Text(l.translationApiSave),
        ),
      ],
    );
  }

  /// Null when the store could not be read — the field still works then.
  String? _statusOf(AppL10n l, OpenCodeProviderAuth? auth) {
    if (auth == null) return null;
    if (!auth.linked) return l.translationOpenCodeKeyNone;
    final preview = auth.keyPreview;
    return preview == null
        ? l.translationOpenCodeKeyOauth
        : l.translationOpenCodeKeySaved(preview);
  }
}
