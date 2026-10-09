import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/navigation/person_chip.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The people involved in a ZenTao bug — reporter, current owner, last editor —
/// as avatar + name fields, lifted out of the flat details table. With chat
/// wired in, each one shows their chat photo and "verified" check and opens
/// a chat with them on tap.
class BugPeopleRow extends ConsumerWidget {
  const BugPeopleRow({super.key, required this.bug, required this.accountId});

  final ZenTaoBugEntity bug;

  /// The ZenTao account the bug was read through (whose chat to use).
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      children: [
        for (final f in fields)
          _PersonField(
            label: f.$1,
            name: f.$2,
            accountId: accountId,
            chip: ref.watch(personChipBuilderProvider),
          ),
      ],
    );
  }
}

class _PersonField extends StatelessWidget {
  const _PersonField({
    required this.label,
    required this.name,
    required this.accountId,
    required this.chip,
  });

  final String label;
  final String name;
  final String accountId;
  final PersonChipBuilder? chip;

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
        switch (chip) {
          final build? => build(
            context,
            accountId: accountId,
            name: name,
            avatarSize: _avatarSize(context),
          ),
          null => Row(
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
        },
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
      width: _avatarSize(context),
      height: _avatarSize(context),
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

/// The people's avatar diameter.
double _avatarSize(BuildContext context) => context.spacing.xl2 * 2;
