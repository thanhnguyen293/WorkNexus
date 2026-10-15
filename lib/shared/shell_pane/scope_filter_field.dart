import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_search_field.dart';
import '../../l10n/app_localizations.dart';

/// A search field for filtering scopes in a tool pane with a 150ms debounce.
class ScopeFilterField extends StatefulWidget {
  const ScopeFilterField({
    super.key,
    this.value = '',
    required this.onChanged,
    this.placeholder,
    this.debounceDuration = const Duration(milliseconds: 150),
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final Duration debounceDuration;
  final bool autofocus;

  @override
  State<ScopeFilterField> createState() => _ScopeFilterFieldState();
}

class _ScopeFilterFieldState extends State<ScopeFilterField> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(ScopeFilterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      widget.onChanged('');
      return;
    }
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        widget.onChanged(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final hint = widget.placeholder ?? l.filterProjects;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      child: AppSearchField(
        controller: _controller,
        hint: hint,
        autofocus: widget.autofocus,
        onChanged: _onQueryChanged,
      ),
    );
  }
}
