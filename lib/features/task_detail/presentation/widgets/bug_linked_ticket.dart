import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/open_zentao_task.dart';
import 'detail_field_link.dart';

/// A story or task a bug is linked to, as an accent link in the classification
/// table: tapping it opens that ticket in the detail panel — fetched from
/// ZenTao first when it has not been synced.
class BugLinkedTicket extends ConsumerStatefulWidget {
  const BugLinkedTicket({
    super.key,
    required this.ticket,
    required this.type,
    required this.id,
    required this.label,
  });

  /// The bug.
  final Ticket ticket;

  /// The ZenTao type of the linked ticket (`story`, `task`).
  final String type;
  final String id;
  final String label;

  @override
  ConsumerState<BugLinkedTicket> createState() => _BugLinkedTicketState();
}

class _BugLinkedTicketState extends ConsumerState<BugLinkedTicket> {
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
