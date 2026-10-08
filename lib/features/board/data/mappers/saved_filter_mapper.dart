import 'dart:convert';

import '../../../../core/database/database.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/value_objects/saved_filter.dart';
import '../../domain/value_objects/saved_view.dart';

/// Serialization for the board's filter presets. Kept in `data/` so
/// [FilterState] stays a pure, JSON-free domain entity (CLAUDE.md 2.1, 3.3).
///
/// `workspaceId` is deliberately not persisted: it is the board's scope, not a
/// filter criterion, so applying a preset never moves you to another workspace.
/// Unknown enum names (a preset saved by a newer build) are dropped rather than
/// throwing — a partially-applied preset beats a crash.
String encodeFilterState(FilterState f) => jsonEncode(<String, dynamic>{
  'savedView': f.savedView.name,
  'providers': [for (final p in f.providers) p.name],
  'accountIds': f.accountIds.toList(),
  'projectIds': f.projectIds.toList(),
  'statuses': [for (final s in f.statuses) s.name],
  'priorities': [for (final p in f.priorities) p.name],
  'severities': f.severities.toList(),
  'assignees': f.assignees.toList(),
  'reviewers': f.reviewers.toList(),
  'bugTypes': f.bugTypes.toList(),
  'resolutions': f.resolutions.toList(),
  'search': f.search,
});

FilterState decodeFilterState(String json) {
  final Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(json);
    map = decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const FilterState();
  }
  return FilterState(
    savedView: _enumByName(SavedView.values, map['savedView']) ?? SavedView.all,
    providers: _enumSet(ProviderType.values, map['providers']),
    accountIds: _stringSet(map['accountIds']),
    projectIds: _stringSet(map['projectIds']),
    statuses: _enumSet(UnifiedStatus.values, map['statuses']),
    priorities: _enumSet(Priority.values, map['priorities']),
    severities: {for (final v in _list(map['severities'])) ?_toInt(v)},
    assignees: _stringSet(map['assignees']),
    reviewers: _stringSet(map['reviewers']),
    bugTypes: _stringSet(map['bugTypes']),
    resolutions: _stringSet(map['resolutions']),
    search: map['search']?.toString() ?? '',
  );
}

SavedFilter savedFilterFromRow(SavedFilterRow r) => SavedFilter(
  id: r.id,
  name: r.name,
  filter: decodeFilterState(r.filterJson),
  createdAt: r.createdAt,
);

SavedFiltersCompanion savedFilterToCompanion(SavedFilter f) =>
    SavedFiltersCompanion.insert(
      id: f.id,
      name: f.name,
      filterJson: encodeFilterState(f.filter),
      createdAt: f.createdAt,
    );

List<Object?> _list(Object? raw) => raw is List ? raw : const [];

int? _toInt(Object? raw) => raw is int ? raw : int.tryParse('$raw');

Set<String> _stringSet(Object? raw) => {
  for (final v in _list(raw)) v.toString(),
};

Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw) => {
  for (final v in _list(raw)) ?_enumByName(values, v),
};

T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw == null) return null;
  final name = raw.toString();
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
