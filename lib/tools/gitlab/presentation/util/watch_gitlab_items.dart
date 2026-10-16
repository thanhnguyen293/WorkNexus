import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/gitlab_item_kind.dart';
import '../providers/gitlab_board_providers.dart';

/// Keeps the open project's [kind] items syncing while a section shows them
/// (the slice its list and board reconcile against). The kind the slice
/// fetches is app-wide, so the section brings it in line with its own.
void watchGitLabItems(
  BuildContext context,
  WidgetRef ref,
  GitLabItemKind kind,
) {
  // Only while on screen: a section the viewport keeps alive off screen must
  // not pull the kind away from the visible one.
  if (ref.watch(gitlabKindProvider) != kind &&
      TickerMode.valuesOf(context).enabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ref.read(gitlabKindProvider.notifier).set(kind);
    });
  }
  ref.watch(gitlabItemsSliceProvider);
}
