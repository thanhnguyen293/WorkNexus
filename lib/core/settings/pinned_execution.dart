import 'package:flutter/foundation.dart';

/// The pin key of ZenTao *project* [projectId]. Products were pinned first,
/// as bare `accountId:productId` keys (still their format, so pins saved by
/// older versions load as they were); ZenTao numbers products and projects
/// apart, so a project's key carries its kind or the two would collide.
String zentaoProjectPinKey(String accountId, String projectId) =>
    'zentao-project:$accountId:$projectId';

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
    this.parentKey,
  });

  final String accountId;
  final String projectId;
  final String executionId;
  final String name;

  /// The pin that brought this one in (a product or project pinned with its
  /// executions), so unpinning that removes exactly these. Null for pins saved
  /// before it was kept, and for an execution pinned on its own: those belong
  /// to their project ([ownerKey]).
  final String? parentKey;

  /// The pin this one goes with: [parentKey], else its project's.
  String get ownerKey => parentKey ?? zentaoProjectPinKey(accountId, projectId);

  PinnedExecution withParent(String key) => PinnedExecution(
    accountId: accountId,
    projectId: projectId,
    executionId: executionId,
    name: name,
    parentKey: key,
  );

  /// Stable identity of the pin (a project may be re-created, but the execution
  /// id is unique within an account), used for toggling and de-duplication.
  String get key => '$accountId:$executionId';

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'projectId': projectId,
    'executionId': executionId,
    'name': name,
    if (parentKey != null) 'parentKey': parentKey,
  };

  factory PinnedExecution.fromJson(Map<String, dynamic> json) =>
      PinnedExecution(
        accountId: json['accountId'] as String,
        projectId: json['projectId'] as String,
        executionId: json['executionId'] as String,
        name: json['name'] as String,
        parentKey: json['parentKey'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is PinnedExecution &&
      other.accountId == accountId &&
      other.projectId == projectId &&
      other.executionId == executionId &&
      other.name == name &&
      other.parentKey == parentKey;

  @override
  int get hashCode =>
      Object.hash(accountId, projectId, executionId, name, parentKey);
}
