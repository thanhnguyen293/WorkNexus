import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/github_item_kind.dart';
import '../providers/github_board_providers.dart';

/// Keeps the open repository's [kind] items syncing while a section shows
/// them (the slice its list and board reconcile against). The kind the slice
/// fetches is app-wide, so the section brings it in line with its own.
void watchGitHubItems(
  BuildContext context,
  WidgetRef ref,
  GitHubItemKind kind,
) {
  // Only while on screen: a section the viewport keeps alive off screen must
  // not pull the kind away from the visible one.
  if (ref.watch(githubKindProvider) != kind &&
      TickerMode.valuesOf(context).enabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ref.read(githubKindProvider.notifier).set(kind);
    });
  }
  ref.watch(githubItemsSliceProvider);
}
