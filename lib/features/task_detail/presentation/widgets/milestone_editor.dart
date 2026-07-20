import 'package:flutter/material.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'metadata_editor_parts.dart';

class MilestoneEditor extends StatefulWidget {
  const MilestoneEditor({
    super.key,
    required this.currentMilestoneId,
    required this.loadOptions,
    required this.onSave,
    required this.onClose,
  });

  final int? currentMilestoneId;
  final Future<Result<List<ProviderMilestoneOption>>> Function() loadOptions;
  final Future<Result<void>> Function(int? milestoneId) onSave;
  final VoidCallback onClose;

  @override
  State<MilestoneEditor> createState() => _MilestoneEditorState();
}

class _MilestoneEditorState extends State<MilestoneEditor> {
  late final Future<Result<List<ProviderMilestoneOption>>> _options;
  late int? _selected = widget.currentMilestoneId;
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
    final result = await widget.onSave(_selected);
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
          hint: l.searchMilestones,
          onChanged: (value) => setState(() => _query = value),
        ),
        Flexible(
          child: FutureBuilder<Result<List<ProviderMilestoneOption>>>(
            future: _options,
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (result case Err<List<ProviderMilestoneOption>>(
                :final failure,
              )) {
                return EditorMessage(
                  message: failure.message,
                  isError: true,
                );
              }
              final options =
                  (result as Ok<List<ProviderMilestoneOption>>).value;
              final query = _query.trim().toLowerCase();
              final visible = query.isEmpty
                  ? options
                  : options
                        .where(
                          (option) =>
                              option.title.toLowerCase().contains(query),
                        )
                        .toList();
              return ListView(
                padding: EdgeInsets.only(bottom: context.spacing.xs),
                shrinkWrap: true,
                children: [
                  EditorOptionTile(
                    title: l.none,
                    selected: _selected == null,
                    onTap: () => setState(() => _selected = null),
                  ),
                  for (final option in visible)
                    EditorOptionTile(
                      title: option.title,
                      selected: _selected == option.id,
                      onTap: () => setState(() => _selected = option.id),
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
