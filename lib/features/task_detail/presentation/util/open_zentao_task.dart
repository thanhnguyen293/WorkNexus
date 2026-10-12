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
) => openZenTaoTicket(
  ref,
  accountId: from.accountId,
  host: Uri.tryParse(from.url ?? '')?.host ?? '',
  type: 'task',
  id: taskId,
);
