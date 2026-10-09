import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';

/// Opens ZenTao [kind] [id] of [account] in the detail panel, fetching it from
/// ZenTao first when the board has not synced it.
Future<Result<void>> openDashboardItem(
  WidgetRef ref,
  Account account,
  DashboardItemKind kind,
  String id,
) async {
  if (!kind.isTicket) {
    return const Err(NotFoundFailure('Todos have no detail view'));
  }
  final opener = ref.read(openTicketIdProvider.notifier);
  final synced = ref.read(ticketByIdProvider('${account.id}:$id'));
  // Bugs, tasks and stories share id numbers: only a synced ticket of the
  // same kind is the one.
  if (synced != null && synced.externalType?.toLowerCase() == kind.name) {
    opener.open(synced.id);
    return const Ok(null);
  }
  final host = Uri.tryParse(account.baseUrl ?? '')?.host ?? '';
  if (host.isEmpty) {
    return const Err(NotFoundFailure('No ZenTao host for this account'));
  }
  final res = await ref
      .read(zenTaoTicketServiceProvider)
      .fetchZenTaoTicket(host: host, type: kind.name, id: id);
  switch (res) {
    case Ok(:final value):
      if (ref.context.mounted) opener.open(value);
      return const Ok(null);
    case Err(:final failure):
      return Err(failure);
  }
}
