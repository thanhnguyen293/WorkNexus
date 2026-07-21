import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'metadata_editor_parts.dart';

typedef SaveTimeTracking =
    Future<Result<void>> Function({
      String? estimate,
      String? spent,
      bool resetEstimate,
      bool resetSpent,
    });

class TimeTrackingEditor extends StatefulWidget {
  const TimeTrackingEditor({
    super.key,
    required this.currentEstimate,
    required this.currentSpent,
    required this.onSave,
    required this.onClose,
  });

  final String? currentEstimate;
  final String? currentSpent;
  final SaveTimeTracking onSave;
  final VoidCallback onClose;

  @override
  State<TimeTrackingEditor> createState() =>
      _TimeTrackingEditorState();
}

class _TimeTrackingEditorState extends State<TimeTrackingEditor> {
  late final TextEditingController _estimate = TextEditingController(
    text: widget.currentEstimate,
  );
  final _spent = TextEditingController();
  bool _resetEstimate = false;
  bool _resetSpent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _estimate.dispose();
    _spent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSave(
      estimate: _estimate.text.trim().isEmpty ? null : _estimate.text.trim(),
      spent: _spent.text.trim().isEmpty ? null : _spent.text.trim(),
      resetEstimate: _resetEstimate,
      resetSpent: _resetSpent,
    );
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
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(l.estimate),
                TextField(
                  controller: _estimate,
                  enabled: !_resetEstimate,
                  decoration: editorInputDecoration(
                    context,
                    hintText: l.estimateDurationHint,
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _resetEstimate,
                  title: Text(l.resetEstimate),
                  onChanged: (value) =>
                      setState(() => _resetEstimate = value ?? false),
                ),
                SizedBox(height: context.spacing.sm),
                _FieldLabel(l.addTimeSpent),
                TextField(
                  controller: _spent,
                  enabled: !_resetSpent,
                  decoration: editorInputDecoration(
                    context,
                    hintText: l.spentDurationHint,
                  ),
                ),
                if ((widget.currentSpent ?? '').isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: context.spacing.sm),
                    child: Text(
                      l.currentTotal(widget.currentSpent!),
                      style: context.typography.bodySm.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _resetSpent,
                  title: Text(l.resetSpentTime),
                  onChanged: (value) =>
                      setState(() => _resetSpent = value ?? false),
                ),
              ],
            ),
          ),
        ),
        EditorFooter(busy: _busy, error: _error, onSave: _save),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Text(
        label,
        style: context.typography.captionStrong.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
