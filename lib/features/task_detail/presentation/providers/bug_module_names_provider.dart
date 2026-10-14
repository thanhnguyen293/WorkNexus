import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/result.dart';

/// A ZenTao product's bug modules as id → path ("Livestream/Share"), keyed by
/// (account id, product id). ZenTao's bug only carries the module id, so the
/// names come from the bug form's module list.
///
/// Kept alive once loaded: that list costs a whole form page and rarely
/// changes, so each product is fetched once per run. A failed fetch is not
/// kept, so reopening the bug retries it.
final bugModuleNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (String, String)>((ref, key) async {
      final (accountId, productId) = key;
      final res = await ref
          .read(zenTaoTicketEditorProvider)
          .bugModules(accountId, productId);
      switch (res) {
        case Ok(:final value):
          ref.keepAlive();
          return {
            for (final module in value)
              module.value: module.label.replaceFirst(RegExp('^/'), ''),
          };
        case Err(:final failure):
          throw failure;
      }
    });
