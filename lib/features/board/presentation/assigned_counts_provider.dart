import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/settings/app_settings.dart';
import '../domain/usecases/count_assigned_to_me.dart';
import '../domain/value_objects/assigned_counts.dart';

/// The sources tree's "assigned to me" counts, from the stored tickets and the
/// current pins (see [CountAssignedToMe]). Rows watch their own number with
/// `select`, so a count change rebuilds only the rows it touches.
final assignedCountsProvider = Provider<AssignedCounts>((ref) {
  final tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  final accounts = ref.watch(lookupsProvider.select((l) => l.accounts));
  final pinnedProjects = ref.watch(
    appSettingsProvider.select((s) => s.pinnedProjects),
  );
  final pinnedExecutions = ref.watch(
    appSettingsProvider.select((s) => s.pinnedExecutions),
  );
  return const CountAssignedToMe()(
    tickets: tickets,
    accounts: accounts.values,
    pinnedProjects: pinnedProjects,
    pinnedExecutions: {for (final e in pinnedExecutions) e.key},
  );
});
