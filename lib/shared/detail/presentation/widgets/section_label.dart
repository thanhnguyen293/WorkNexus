import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Small uppercase section heading used across the detail tabs.
///
/// A widget (not a `_buildXxx` helper) per rule 6.2 — `const`, narrow rebuild
/// scope, reusable within the feature.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.typography.label.copyWith(
        fontWeight: FontWeight.w600,
        color: context.colors.textTertiary,
      ),
    );
  }
}
