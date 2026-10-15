import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../domain/usecases/compute_zentao_metrics.dart';

final computeZentaoMetricsProvider =
    Provider.family<AsyncValue<ToolMetrics>, String>((ref, accountId) {
      final ticketsAsync = ref.watch(ticketsProvider);
      return ticketsAsync.whenData(
        (tickets) => const ComputeZentaoMetrics().call(
          tickets: tickets,
          accountId: accountId,
        ),
      );
    });
