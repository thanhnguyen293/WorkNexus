import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nav_ids.dart';

/// The key of an account's place, for [collapsedPanesProvider].
String paneKey(String accountId, SectionId section) =>
    '$accountId|${section.value}';

/// The places whose navigation pane the reader folded away (with the
/// pane's collapse button) — kept for the session, so the pane stays folded
/// across a trip to another place.
class CollapsedPanes extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void collapse(String key) => state = {...state, key};

  void expand(String key) => state = {...state}..remove(key);
}

final collapsedPanesProvider = NotifierProvider<CollapsedPanes, Set<String>>(
  CollapsedPanes.new,
);
