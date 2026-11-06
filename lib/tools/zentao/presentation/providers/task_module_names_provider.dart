import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/result.dart';
import 'bug_module_names_provider.dart';
import 'zentao_board_providers.dart';

/// A ZenTao execution's task modules as id → path ("Livestream/Share"),
/// keyed by (account id, execution id), from its task form's module list.
/// Kept alive once loaded, like [bugModuleNamesProvider]; a failed fetch is
/// not kept.
final taskModuleNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (String, String)>((ref, key) async {
      final (accountId, executionId) = key;
      final res = await ref
          .read(zenTaoTicketEditorProvider)
          .taskOptions(accountId, executionId);
      switch (res) {
        case Ok(:final value):
          ref.keepAlive();
          return {
            for (final module in value.modules)
              module.value: module.label.replaceFirst(RegExp('^/'), ''),
          };
        case Err(:final failure):
          throw failure;
      }
    });

/// The module names of the board on screen: the bug board's product
/// ([bugs]) or the task board's execution. Empty until one is picked.
final zentaoBoardModuleNamesProvider = Provider.autoDispose
    .family<AsyncValue<Map<String, String>>, bool>((ref, bugs) {
      if (bugs) {
        final product = ref.watch(selectedZenTaoProductProvider);
        if (product == null) return const AsyncData({});
        return ref.watch(
          bugModuleNamesProvider((product.accountId, product.productId)),
        );
      }
      final execution = ref.watch(selectedZenTaoExecutionProvider);
      if (execution == null) return const AsyncData({});
      return ref.watch(
        taskModuleNamesProvider((execution.accountId, execution.executionId)),
      );
    });
