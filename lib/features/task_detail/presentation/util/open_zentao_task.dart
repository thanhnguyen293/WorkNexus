import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/open_zentao_ticket.dart';

/// Opens ZenTao task [taskId] — a parent or subtask of [from] — in the detail
/// panel, fetching it from ZenTao first when it has not been synced.
Future<Result<void>> openZenTaoTask(
  WidgetRef ref,
  Ticket from,
  String taskId,
) => openZenTaoLinked(ref, from, 'task', taskId);

/// Opens ZenTao [type] (`task`, `story`, `bug`) [id] linked from [from] in the
/// detail panel, on [from]'s account and host, fetching it first when it has
/// not been synced.
Future<Result<void>> openZenTaoLinked(
  WidgetRef ref,
  Ticket from,
  String type,
  String id,
) => openZenTaoTicket(
  ref,
  accountId: from.accountId,
  host: Uri.tryParse(from.url ?? '')?.host ?? '',
  type: type,
  id: id,
);
