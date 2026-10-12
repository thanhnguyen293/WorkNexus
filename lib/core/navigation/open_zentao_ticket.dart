import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../error/result.dart';
import 'navigation_providers.dart';

/// Opens ZenTao [type] [id] in the detail slide-over, fetching it from the
/// ZenTao account on [host] first when the board has not synced it.
///
/// Both providers are read before the fetch: the widget that asked may be gone
/// by the time it answers (a notification card drops out of the list once
/// read), and the ticket should still open.
Future<Result<void>> openZenTaoTicket(
  WidgetRef ref, {
  String? accountId,
  required String host,
  required String type,
  required String id,
}) async {
  final nav = ref.read(appNavProvider.notifier);
  final resolve = ref.read(resolveZenTaoTicketProvider);
  final res = await resolve(
    accountId: accountId,
    host: host,
    type: type,
    id: id,
  );
  switch (res) {
    case Ok(:final value):
      nav.openTicket(value);
      return const Ok(null);
    case Err(:final failure):
      return Err(failure);
  }
}
