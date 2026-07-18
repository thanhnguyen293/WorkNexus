import 'package:flutter/material.dart';

import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'widgets/assign_dialog.dart';
import 'widgets/resolve_dialog.dart';

/// The Assign / Resolve action row shown under the detail header. Only rendered
/// for providers whose write actions are implemented (ZenTao today).
class TicketActionsBar extends StatelessWidget {
  const TicketActionsBar({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    if (ticket.providerType != ProviderType.zentao) {
      return const SizedBox.shrink();
    }
    final isBug = (ticket.externalType ?? '').toLowerCase() == 'bug';
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Assign',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => AssignDialog(ticket: ticket),
            ),
          ),
          if (isBug) ...[
            SizedBox(width: context.spacing.md),
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Resolve',
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => ResolveDialog(ticket: ticket),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton.outlinedNeutral(
      size: AppButtonSize.small,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          SizedBox(width: context.spacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
