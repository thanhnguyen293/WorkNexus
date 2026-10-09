import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/translation_api_config.dart';
import '../../domain/value_objects/translation_api_preset.dart';
import '../translation_api_providers.dart';
import '../../../../core/widgets/connection_text_field.dart';

/// The form to translate with the user's own API key (Gemini, Groq,
/// OpenRouter, a local Ollama or any OpenAI-compatible endpoint) instead of the
/// OpenCode CLI. Left unset, OpenCode keeps doing the translating.
class TranslationApiForm extends ConsumerWidget {
  const TranslationApiForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return switch (ref.watch(translationApiConfigProvider)) {
      AsyncData(:final value) => _ApiForm(
        saved: value.valueOrNull,
        loadFailed: value.isErr,
      ),
      AsyncError() => AppInlineNote(
        text: l.translationApiLoadFailed,
        isError: true,
      ),
      _ => const AppInlineSpinner(),
    };
  }
}

class _ApiForm extends ConsumerStatefulWidget {
  const _ApiForm({required this.saved, required this.loadFailed});

  final TranslationApiConfig? saved;
  final bool loadFailed;

  @override
  ConsumerState<_ApiForm> createState() => _ApiFormState();
}

class _ApiFormState extends ConsumerState<_ApiForm> {
  late TranslationApiPreset _preset;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _key;
  late bool _enabled;
  var _obscure = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = widget.saved;
    _preset = TranslationApiPreset.byId(saved?.presetId ?? 'gemini');
    _baseUrl = TextEditingController(text: saved?.baseUrl ?? _preset.baseUrl);
    _model = TextEditingController(text: saved?.model ?? _preset.defaultModel);
    _key = TextEditingController(text: saved?.apiKey ?? '');
    _enabled = saved?.enabled ?? true;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  void _pick(TranslationApiPreset preset) => setState(() {
    _preset = preset;
    if (preset != TranslationApiPreset.custom) {
      _baseUrl.text = preset.baseUrl;
      _model.text = preset.defaultModel;
    }
    _error = null;
  });

  bool get _canSave =>
      !_saving &&
      _baseUrl.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      (!_preset.needsKey || _key.text.trim().isNotEmpty);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(translationApiControllerProvider.notifier)
        .save(
          TranslationApiConfig(
            presetId: _preset.id,
            baseUrl: _baseUrl.text.trim(),
            model: _model.text.trim(),
            apiKey: _key.text.trim(),
            enabled: _enabled,
          ),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = result.isErr
          ? AppL10n.of(context).translationApiSaveFailed
          : null;
    });
  }

  Future<void> _remove() async {
    await ref.read(translationApiControllerProvider.notifier).clear();
    if (!mounted) return;
    setState(() {
      _key.clear();
      _enabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final keyUrl = _preset.keyUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.loadFailed) ...[
          AppInlineNote(text: l.translationApiLoadFailed, isError: true),
          SizedBox(height: context.spacing.lg),
        ],
        Text(
          l.translationApiProvider,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        SearchableDropdownField<TranslationApiPreset>(
          items: TranslationApiPreset.all,
          value: _preset,
          searchHint: l.translationApiProvider,
          emptyLabel: l.noMatches,
          labelOf: (p) => p == TranslationApiPreset.custom
              ? l.translationApiCustom
              : p.name,
          onChanged: _pick,
        ),
        SizedBox(height: context.spacing.lg),
        if (_preset == TranslationApiPreset.custom) ...[
          ConnectionTextField(
            label: l.translationApiBaseUrl,
            controller: _baseUrl,
            hint: l.translationApiBaseUrlHint,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.spacing.lg),
        ],
        ConnectionTextField(
          label: l.translationApiModel,
          controller: _model,
          onChanged: (_) => setState(() {}),
        ),
        if (_preset.needsKey) ...[
          SizedBox(height: context.spacing.lg),
          ConnectionTextField(
            label: l.translationApiKey,
            controller: _key,
            obscure: _obscure,
            onChanged: (_) => setState(() {}),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (keyUrl != null)
                  TextButton(
                    onPressed: () => openExternally(keyUrl),
                    child: Text(l.translationApiGetKey),
                  ),
                TextButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  child: Text(_obscure ? l.openCodeShowKey : l.openCodeHideKey),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: context.spacing.lg),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.translationApiUse,
                    style: context.typography.body.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    l.translationApiUseHint,
                    style: context.typography.caption.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _enabled,
              onChanged: (on) => setState(() => _enabled = on),
            ),
          ],
        ),
        if (_error != null) ...[
          SizedBox(height: context.spacing.md),
          AppInlineNote(text: _error!, isError: true),
        ],
        SizedBox(height: context.spacing.lg),
        Row(
          children: [
            AppButton.filled(
              isLoading: _saving,
              onPressed: _canSave ? _save : null,
              child: Text(l.translationApiSave),
            ),
            if (widget.saved != null) ...[
              SizedBox(width: context.spacing.md),
              AppButton.textNeutral(
                onPressed: _remove,
                child: Text(l.translationApiRemove),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
