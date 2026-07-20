import 'package:flutter/material.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/provider_color.dart';
import '../../../../l10n/app_localizations.dart';
import 'metadata_editor_parts.dart';

class LabelsEditor extends StatefulWidget {
  const LabelsEditor({
    super.key,
    required this.currentLabels,
    required this.loadOptions,
    required this.onSave,
    required this.onClose,
  });

  final List<String> currentLabels;
  final Future<Result<List<ProviderLabelOption>>> Function() loadOptions;
  final Future<Result<void>> Function(List<String> labels) onSave;
  final VoidCallback onClose;

  @override
  State<LabelsEditor> createState() => _LabelsEditorState();
}

class _LabelsEditorState extends State<LabelsEditor> {
  late final Future<Result<List<ProviderLabelOption>>> _options;
  late final Set<String> _selected = widget.currentLabels.toSet();
  final _search = TextEditingController();
  String _query = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _options = widget.loadOptions();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSave(_selected.toList());
    if (!mounted) return;
    if (result case Err<void>(:final failure)) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
      return;
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorSearchField(
          controller: _search,
          hint: l.searchLabels,
          onChanged: (value) => setState(() => _query = value),
        ),
        Flexible(
          child: FutureBuilder<Result<List<ProviderLabelOption>>>(
            future: _options,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (result case Err<List<ProviderLabelOption>>(:final failure)) {
                return EditorMessage(
                  message: failure.message,
                  isError: true,
                );
              }
              final options = (result as Ok<List<ProviderLabelOption>>).value;
              final query = _query.trim().toLowerCase();
              final visible = query.isEmpty
                  ? options
                  : options
                        .where(
                          (option) => option.name.toLowerCase().contains(query),
                        )
                        .toList();
              if (visible.isEmpty) {
                return EditorMessage(message: l.noProjectLabels);
              }
              return ListView(
                padding: EdgeInsets.only(bottom: context.spacing.xs),
                shrinkWrap: true,
                children: [
                  for (final option in visible)
                    EditorOptionTile(
                      title: option.name,
                      selected: _selected.contains(option.name),
                      leading: _LabelSwatch(color: option.color),
                      onTap: () => setState(() {
                        if (!_selected.remove(option.name)) {
                          _selected.add(option.name);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
        ),
        EditorFooter(busy: _busy, error: _error, onSave: _save),
      ],
    );
  }
}

class _LabelSwatch extends StatelessWidget {
  const _LabelSwatch({required this.color});

  final String? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.spacing.xl,
      height: context.spacing.xl,
      decoration: BoxDecoration(
        color: providerColorFromHex(color) ?? context.colors.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}
