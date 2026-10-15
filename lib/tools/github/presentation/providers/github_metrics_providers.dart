import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../domain/usecases/compute_github_metrics.dart';

final computeGithubMetricsProvider =
    Provider.family<AsyncValue<ToolMetrics>, String>((ref, accountId) {
      final ticketsAsync = ref.watch(ticketsProvider);
      return ticketsAsync.whenData(
        (tickets) => const ComputeGithubMetrics()(
          tickets: tickets,
          accountId: accountId,
        ),
      );
    });
