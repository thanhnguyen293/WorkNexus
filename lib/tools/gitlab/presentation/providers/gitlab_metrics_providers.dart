import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../domain/usecases/compute_gitlab_metrics.dart';
import 'gitlab_board_providers.dart';

final computeGitlabMetricsProvider =
    Provider.family<AsyncValue<ToolMetrics>, String>((ref, accountId) {
      final ticketsAsync = ref.watch(ticketsProvider);
      final projectsAsync = ref.watch(gitlabProjectsProvider(accountId));

      return ticketsAsync.when(
        data: (tickets) {
          final projectCount = projectsAsync.asData?.value.length ?? 0;
          return AsyncData(
            const ComputeGitlabMetrics()(
              tickets: tickets,
              projectCount: projectCount,
              accountId: accountId,
            ),
          );
        },
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
      );
    });
