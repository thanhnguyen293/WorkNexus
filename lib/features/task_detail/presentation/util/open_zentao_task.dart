import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';

/// Opens ZenTao task [taskId] — a parent or subtask of [from] — in the detail
/// panel, fetching it from ZenTao first when it has not been synced.
Future<Result<void>> openZenTaoTask(
  WidgetRef ref,
  Ticket from,
  String taskId,
) async {
  final opener = ref.read(openTicketIdProvider.notifier);
  final synced = ref.read(ticketByIdProvider('${from.accountId}:$taskId'));
  // Bugs and tasks share id numbers: only a synced *task* is the one.
  if (synced != null && synced.externalType?.toLowerCase() == 'task') {
    opener.open(synced.id);
    return const Ok(null);
  }
  final host = Uri.tryParse(from.url ?? '')?.host ?? '';
  if (host.isEmpty) {
    return const Err(NotFoundFailure('No ZenTao host for this task'));
  }
  final res = await ref
      .read(zenTaoTicketServiceProvider)
      .fetchZenTaoTicket(host: host, type: 'task', id: taskId);
  switch (res) {
    case Ok(:final value):
      if (ref.context.mounted) opener.open(value);
      return const Ok(null);
    case Err(:final failure):
      return Err(failure);
  }
}
