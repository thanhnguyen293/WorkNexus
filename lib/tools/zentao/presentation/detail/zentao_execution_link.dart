import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/navigation/open_zentao_execution.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/detail/presentation/widgets/detail_field_link.dart';

/// The execution a ticket belongs to, as a link that opens that execution's task
/// board (closing the detail panel), the way the sidebar does.
class ZenTaoExecutionLink extends ConsumerWidget {
  const ZenTaoExecutionLink({super.key, required this.execution});

  final ProviderExecution execution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openZenTaoExecutionProvider);
    if (open == null) {
      return Text(
        execution.name,
        textAlign: TextAlign.right,
        style: context.typography.secondary.copyWith(
          color: context.colors.textPrimary,
        ),
      );
    }
    return DetailFieldLink(
      label: execution.name,
      onTap: () => open(context, ref, execution),
    );
  }
}
