import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../domain/usecases/compute_zentao_metrics.dart';

final computeZentaoMetricsProvider =
    Provider.family<AsyncValue<ToolMetrics>, String>((ref, accountId) {
      final ticketsAsync = ref.watch(ticketsProvider);
      final account = ref
          .watch(accountsProvider)
          .asData
          ?.value
          .where((a) => a.id == accountId)
          .firstOrNull;
      if (account == null) return const AsyncLoading();
      return ticketsAsync.whenData(
        (tickets) => const ComputeZentaoMetrics().call(
          tickets: tickets,
          account: account,
        ),
      );
    });
