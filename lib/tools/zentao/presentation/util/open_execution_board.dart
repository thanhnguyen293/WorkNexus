import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';

/// Switches to [execution]'s task board; selecting it makes each column load
/// the first page of its status view into the DB, which the board reads
/// reactively. Matches `OpenZenTaoExecution`, so a ticket's Execution field
/// opens the board the way the sidebar does.
Future<void> openExecutionBoard(
  BuildContext context,
  WidgetRef ref,
  ProviderExecution execution,
) async {
  final nav = ref.read(appNavProvider.notifier);
  nav.selectAccount(execution.accountId);
  nav.selectSection(const SectionId('zentao.tasks'));
  nav.selectScope(execution.id);
  // Selecting a task board and a bug board are mutually exclusive, so clear
  // the product selection first.
  ref.read(selectedZenTaoProductProvider.notifier).clear();
  ref.read(selectedZenTaoExecutionProvider.notifier).select(execution);
  // Restore this board's own filter; a first visit opens unfiltered.
  ref.read(filterStateProvider.notifier).openBoard(ref.read(boardKeyProvider));
}
