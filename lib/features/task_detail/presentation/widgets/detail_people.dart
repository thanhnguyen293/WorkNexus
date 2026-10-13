import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/person_chip.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Who holds the ticket now and, for a ZenTao bug, who reported it — in the
/// detail header beside the actions, since "whose is it" is the first thing
/// asked of a ticket. A ZenTao person shows their chat photo and opens a chat
/// on tap when chat is wired in; anyone else gets an initials avatar.
class DetailPeople extends ConsumerWidget {
  const DetailPeople({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final bug = switch (ticket.providerEntity) {
      final ZenTaoBugEntity b => b,
      _ => null,
    };
    final assignee = (bug?.assignedTo ?? ticket.assignee ?? '').trim();
    final reporter = (bug?.openedBy ?? '').trim();
    final chip = ticket.providerType == ProviderType.zentao
        ? ref.watch(personChipBuilderProvider)
        : null;
    return Wrap(
      spacing: context.spacing.xl2,
      runSpacing: context.spacing.lg,
      children: [
        _PersonField(
          label: l.assignedTo,
          name: assignee,
          accountId: ticket.accountId,
          chip: chip,
        ),
        if (reporter.isNotEmpty)
          _PersonField(
            label: l.openedBy,
            name: reporter,
            accountId: ticket.accountId,
            chip: chip,
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
        if (name.isEmpty)
          Text(
            AppL10n.of(context).unassigned,
            style: context.typography.secondary.copyWith(color: c.textTertiary),
          )
        else
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
