import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/navigation_providers.dart';
import 'contextual_search_field.dart';

/// The title bar's ticket search, shown only where tickets are what the
/// user looks for: not over a mini app (a web page of its own), and not in
/// chat, whose list has its own search — there it read "Search in ZenTao…"
/// yet only ever found tasks and bugs.
class TitleBarSearch extends ConsumerWidget {
  const TitleBarSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offTopic =
        ref.watch(miniAppOnScreenProvider) || ref.watch(chatOpenProvider);
    // Unmounted, not just hidden: its Ctrl/Cmd+K handler goes with it.
    return offTopic ? const SizedBox.shrink() : const ContextualSearchField();
  }
}
