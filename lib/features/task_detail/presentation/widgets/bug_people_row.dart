import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The people involved in a ZenTao bug — reporter, current owner, last editor —
/// as compact avatar + name fields, lifted out of the flat details table.
class BugPeopleRow extends StatelessWidget {
  const BugPeopleRow({super.key, required this.bug});

  final ZenTaoBugEntity bug;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final fields = <(String, String)>[
      if ((bug.openedBy ?? '').isNotEmpty) (l.openedBy, bug.openedBy!),
      if ((bug.assignedTo ?? '').isNotEmpty) (l.assignedTo, bug.assignedTo!),
      if ((bug.lastEditedBy ?? '').isNotEmpty)
        (l.lastEdited, bug.lastEditedBy!),
    ];
    if (fields.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: context.spacing.xl2,
      runSpacing: context.spacing.lg,
      children: [for (final f in fields) _PersonField(label: f.$1, name: f.$2)],
    );
  }
}

class _PersonField extends StatelessWidget {
  const _PersonField({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.typography.caption.copyWith(color: c.textTertiary),
        ),
        SizedBox(height: context.spacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(name),
            SizedBox(width: context.spacing.sm),
            Text(
              name,
              style: context.typography.secondary.copyWith(
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.mixT(c.accent, 0.15),
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        _initials(name),
        style: context.typography.captionSm.copyWith(
          fontWeight: FontWeight.w600,
          color: c.accent,
        ),
      ),
    );
  }

  String _initials(String name) {
    final letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return '?';
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }
}
