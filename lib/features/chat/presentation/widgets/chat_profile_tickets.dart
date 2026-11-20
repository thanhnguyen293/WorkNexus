import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_person_providers.dart';
import 'chat_profile_section.dart';

/// A person's open synced bugs and tasks — assigned to them, then reported by
/// them — each opening in the detail panel. Hidden when there are none.
class ChatProfileTickets extends ConsumerWidget {
  const ChatProfileTickets({
    super.key,
    required this.accountId,
    required this.handle,
  });

  final String accountId;

  /// Their ZenTao login.
  final String handle;

  /// Rows shown per group before "+N more".
  static const _shown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final (:assigned, :reported) = ref.watch(
      chatPersonTicketsProvider((accountId: accountId, handle: handle)),
    );
    if (assigned.isEmpty && reported.isEmpty) return const SizedBox.shrink();
    List<Widget> group(String label, List<Ticket> tickets) => [
      if (tickets.isNotEmpty) ...[
        _GroupLabel('$label · ${tickets.length}'),
        ChatProfileExpandableRows(
          shown: _shown,
          rows: [for (final t in tickets) _TicketRow(t)],
        ),
      ],
    ];
    return ChatProfileSection(
      title: l.chatProfileOpenWork,
      count: assigned.length + reported.length,
      children: [
        ...group(l.chatProfileAssigned, assigned),
        ...group(l.chatProfileReported, reported),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.xl, s.xs),
      child: Text(
        text,
        style: context.typography.captionStrong.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _TicketRow extends ConsumerWidget {
  const _TicketRow(this.ticket);

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return HoverSurface(
      semanticLabel: ticket.title,
      onTap: () {
        ref.read(appNavProvider.notifier).openTicket(ticket.id);
        Navigator.of(context).pop();
      },
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
      child: Row(
        children: [
          ZenTaoKindIcon(ticket.externalType),
          SizedBox(width: s.lg),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '#${ticket.externalKey}  ',
                    style: context.typography.body.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                  TextSpan(text: ticket.title),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body.copyWith(color: c.textPrimary),
            ),
          ),
          SizedBox(width: s.md),
          TintedPill(
            color: statusColor(c, ticket.status),
            label: statusLabel(l, ticket.status),
          ),
        ],
      ),
    );
  }
}
