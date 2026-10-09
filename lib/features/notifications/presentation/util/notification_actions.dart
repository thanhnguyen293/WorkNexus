import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../providers/notification_providers.dart';

const _ticketTypes = {'bug', 'task', 'story'};

/// Opens what [n] links to and marks it read. A bug, task or story opens in
/// the detail panel (fetched from ZenTao when the board has not synced it);
/// anything else opens in the browser.
Future<void> openNotification(
  BuildContext context,
  WidgetRef ref,
  ZenTaoNotification n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppL10n.of(context).notificationsOpenFailed;
  if (!n.read) {
    unawaited(
      runNotificationCommand(
        context,
        ref,
        (r) => r.markRead(n.accountId, id: n.id),
      ),
    );
  }
  final type = n.objectType;
  final id = n.objectId;
  final url = n.url;
  if (type != null && id != null && _ticketTypes.contains(type)) {
    final opener = ref.read(openTicketIdProvider.notifier);
    final synced = ref.read(ticketByIdProvider('${n.accountId}:$id'));
    // Bugs, tasks and stories share id numbers: only the same kind matches.
    if (synced != null && synced.externalType?.toLowerCase() == type) {
      opener.open(synced.id);
      return;
    }
    final host = Uri.tryParse(url ?? '')?.host ?? '';
    final res = await ref
        .read(zenTaoTicketServiceProvider)
        .fetchZenTaoTicket(host: host, type: type, id: id);
    if (res case Ok(:final value)) {
      opener.open(value);
      return;
    }
  }
  if (url != null && url.startsWith('http')) {
    await openExternally(url);
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text(failed)));
}

/// Runs a notification [command] and reports a failure in a snackbar (the
/// list itself has already been restored from the server by then).
Future<void> runNotificationCommand(
  BuildContext context,
  WidgetRef ref,
  Future<Result<void>> Function(NotificationRepository repository) command,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppL10n.of(context).notificationsActionFailed;
  final res = await command(ref.read(notificationRepositoryProvider));
  if (res is Err) messenger.showSnackBar(SnackBar(content: Text(failed)));
}
