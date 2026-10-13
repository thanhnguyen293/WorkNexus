import 'package:flutter/material.dart';

import '../../../../core/widgets/app_button.dart';

/// How prominent an [MrAsyncButton] is.
enum MrButtonKind { primary, secondary }

/// A merge-request widget's action button that shows a spinner — and ignores
/// further presses — until the action it started has finished (a rebase can
/// take a while).
class MrAsyncButton extends StatefulWidget {
  const MrAsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = MrButtonKind.primary,
  });

  final String label;
  final Future<void> Function() onPressed;
  final MrButtonKind kind;

  @override
  State<MrAsyncButton> createState() => _MrAsyncButtonState();
}

class _MrAsyncButtonState extends State<MrAsyncButton> {
  bool _busy = false;

  Future<void> _press() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _busy ? null : _press;
    final label = Text(widget.label);
    return switch (widget.kind) {
      MrButtonKind.primary => AppButton.filled(
        size: AppButtonSize.small,
        isLoading: _busy,
        onPressed: onPressed,
        child: label,
      ),
      MrButtonKind.secondary => AppButton.outlinedNeutral(
        size: AppButtonSize.small,
        isLoading: _busy,
        onPressed: onPressed,
        child: label,
      ),
    };
  }
}
