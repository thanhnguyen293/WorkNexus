import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Selectable monospace code on a subtle boxed surface: Markdown code
/// fences and chat code messages.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key, required this.fontSize});

  final String code;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.lg),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: c.border),
      ),
      child: SelectableText(
        code,
        style: context.typography.mono.copyWith(
          fontSize: fontSize,
          color: c.textPrimary,
          height: 1.45,
        ),
      ),
    );
  }
}
