import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/open_zentao_task.dart';
import 'detail_field_link.dart';

/// A ZenTao story, task or bug a ticket links to, as an accent link in its
/// sidebar table: tapping it opens that ticket in the detail panel — fetched
/// from ZenTao first when it has not been synced.
class ZenTaoLinkedTicket extends ConsumerStatefulWidget {
  const ZenTaoLinkedTicket({
    super.key,
    required this.ticket,
    required this.type,
    required this.id,
    required this.label,
  });

  /// The ticket the link is on.
  final Ticket ticket;

  /// The ZenTao type of the linked ticket (`story`, `task`, `bug`).
  final String type;
  final String id;
  final String label;

  @override
  ConsumerState<ZenTaoLinkedTicket> createState() => _ZenTaoLinkedTicketState();
}

class _ZenTaoLinkedTicketState extends ConsumerState<ZenTaoLinkedTicket> {
  bool _opening = false;

  Future<void> _open() async {
    final l = AppL10n.of(context);
    setState(() => _opening = true);
    final res = await openZenTaoLinked(
      ref,
      widget.ticket,
      widget.type,
      widget.id,
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (res case Err(:final failure)) {
      showAppSnack(context, l.actionFailed(failure.message), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      DetailFieldLink(label: widget.label, onTap: _open, busy: _opening);
}
