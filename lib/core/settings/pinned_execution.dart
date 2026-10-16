import 'package:flutter/foundation.dart';

/// A pinned ZenTao execution, surfaced in the sources tree's per-account "Pinned"
/// area. Unlike pinned products (stored as bare `"accountId:productId"` keys and
/// resolved against the always-loaded products list), executions are only ever
/// fetched per-project, so the pin carries enough to render + open the row
/// without re-fetching its project's executions. Persisted so pins survive
/// restarts.
@immutable
class PinnedExecution {
  const PinnedExecution({
    required this.accountId,
    required this.projectId,
    required this.executionId,
    required this.name,
  });

  final String accountId;
  final String projectId;
  final String executionId;
  final String name;

  /// Stable identity of the pin (a project may be re-created, but the execution
  /// id is unique within an account), used for toggling and de-duplication.
  String get key => '$accountId:$executionId';

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'projectId': projectId,
    'executionId': executionId,
    'name': name,
  };

  factory PinnedExecution.fromJson(Map<String, dynamic> json) =>
      PinnedExecution(
        accountId: json['accountId'] as String,
        projectId: json['projectId'] as String,
        executionId: json['executionId'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is PinnedExecution &&
      other.accountId == accountId &&
      other.projectId == projectId &&
      other.executionId == executionId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(accountId, projectId, executionId, name);
}
