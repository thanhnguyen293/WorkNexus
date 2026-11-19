import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The small uppercase heading over a group of the "Thầy vô" card's
/// sections, so the settings read as a few steps instead of one long list.
class PanicGroupLabel extends StatelessWidget {
  const PanicGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(s.xl2, s.xl2, s.xl2, s.md),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.typography.label.copyWith(color: c.textTertiary),
      ),
    );
  }
}
