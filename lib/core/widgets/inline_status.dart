import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The small centered spinner a settings card shows while its slot is still
/// loading. Sized off the spacing ramp so it stays proportional to the card.
class AppInlineSpinner extends StatelessWidget {
  const AppInlineSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
        child: SizedBox(
          width: context.spacing.xl2,
          height: context.spacing.xl2,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// A short line of explanatory — or, with [isError], failing — text inside a
/// card or filter group. The quiet counterpart to a snackbar, for state that
/// belongs next to the thing it describes.
class AppInlineNote extends StatelessWidget {
  const AppInlineNote({required this.text, this.isError = false, super.key});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: context.typography.bodySm.copyWith(
        color: isError ? c.error : c.textTertiary,
      ),
    );
  }
}
