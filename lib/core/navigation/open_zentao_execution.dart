import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/adapters/provider_adapter.dart';

/// Opens a ZenTao execution's task board, the way picking it in the sidebar
/// does.
typedef OpenZenTaoExecution =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      ProviderExecution execution,
    );

/// The board's "open this execution", wired in by the app so other features
/// (a bug's Execution field) open it without importing the board. Null (tests)
/// means there is nothing to open.
final openZenTaoExecutionProvider = Provider<OpenZenTaoExecution?>(
  (ref) => null,
);
