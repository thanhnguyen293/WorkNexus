import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'translation_api_fields.dart';
import 'translation_model_picker.dart';
import 'translation_opencode_key_field.dart';

/// Picks the one backend that translates: the OpenCode CLI, or an
/// OpenAI-compatible endpoint with the user's own key (Gemini, Groq,
/// OpenRouter, a local Ollama, a custom URL). Only the chosen provider's models
/// are offered.
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
  var _obscure = true;
  var _saving = false;
  String? _error;

  static const _choices = [
    TranslationApiPreset.openCode,
    ...TranslationApiPreset.all,
  ];

  @override
  void initState() {
    super.initState();
    final saved = widget.saved;
    // A saved key that is switched off means OpenCode is the one translating.
    _preset = saved != null && saved.isUsable
        ? TranslationApiPreset.byId(saved.presetId)
        : TranslationApiPreset.openCode;
    final shown = saved != null && saved.presetId == _preset.id ? saved : null;
    _baseUrl = TextEditingController(text: shown?.baseUrl ?? _preset.baseUrl);
    _model = TextEditingController(text: shown?.model ?? _preset.defaultModel);
    _key = TextEditingController(text: shown?.apiKey ?? '');
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _pick(TranslationApiPreset preset) async {
    final saved = widget.saved;
    // Coming back to the saved provider restores its key and model rather
    // than the preset's defaults.
    final restore = saved != null && saved.presetId == preset.id;
    setState(() {
      _preset = preset;
      _baseUrl.text = restore ? saved.baseUrl : preset.baseUrl;
      _model.text = restore ? saved.model : preset.defaultModel;
      _key.text = restore ? saved.apiKey : '';
      _error = null;
    });
    // OpenCode needs nothing more, so it takes over at once; the saved key is
    // kept (switched off) for switching back.
    // Picking the saved provider again switches its key straight back on.
    if (preset.isOpenCode && saved != null && saved.enabled) {
      await _persist(saved.copyWith(enabled: false));
    } else if (restore && !saved.enabled) {
      await _persist(saved.copyWith(enabled: true));
    }
  }

  bool get _canSave =>
      !_saving &&
      _baseUrl.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      (!_preset.needsKey || _key.text.trim().isNotEmpty);

  Future<void> _save() => _persist(
    TranslationApiConfig(
      presetId: _preset.id,
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      apiKey: _key.text.trim(),
    ),
  );

  Future<void> _persist(TranslationApiConfig config) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // Taken before the save: it refreshes the saved config, which can rebuild
    // this form from scratch, and the confirmation must still show then.
    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    final inForce = config.enabled
        ? TranslationApiPreset.byId(config.presetId)
        : TranslationApiPreset.openCode;
    final result = await ref
        .read(translationApiControllerProvider.notifier)
        .save(config);
    if (result.isOk) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.translationApiSaved(_labelOf(l, inForce)))),
      );
    }
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
      _preset = TranslationApiPreset.openCode;
      _key.clear();
    });
  }

  String _labelOf(AppL10n l, TranslationApiPreset p) => switch (p) {
    TranslationApiPreset.openCode => l.translationProviderOpenCode,
    TranslationApiPreset.custom => l.translationApiCustom,
    _ => p.name,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.loadFailed) ...[
          AppInlineNote(text: l.translationApiLoadFailed, isError: true),
          SizedBox(height: context.spacing.lg),
        ],
        _FieldLabel(l.translationApiProvider),
        SearchableDropdownField<TranslationApiPreset>(
          items: _choices,
          value: _preset,
          searchHint: l.translationApiProvider,
          emptyLabel: l.noMatches,
          labelOf: (p) => _labelOf(l, p),
          onChanged: _pick,
        ),
        SizedBox(height: context.spacing.lg),
        if (_preset.isOpenCode) ...[
          _FieldLabel(l.translationApiModel),
          const TranslationModelPicker(),
          SizedBox(height: context.spacing.lg),
          const TranslationOpenCodeKeyField(),
        ] else
          TranslationApiFields(
            preset: _preset,
            baseUrl: _baseUrl,
            model: _model,
            apiKey: _key,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onChanged: () => setState(() {}),
          ),
        if (_error != null) ...[
          SizedBox(height: context.spacing.md),
          AppInlineNote(text: _error!, isError: true),
        ],
        if (!_preset.isOpenCode) ...[
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
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.spacing.xs),
    child: Text(
      text,
      style: context.typography.captionStrong.copyWith(
        color: context.colors.textSecondary,
      ),
    ),
  );
}
