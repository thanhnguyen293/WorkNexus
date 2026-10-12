import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/open_zentao_ticket.dart';
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
  return openZenTaoTicket(
    ref,
    accountId: account.id,
    host: Uri.tryParse(account.baseUrl ?? '')?.host ?? '',
    type: kind.name,
    id: id,
  );
}
