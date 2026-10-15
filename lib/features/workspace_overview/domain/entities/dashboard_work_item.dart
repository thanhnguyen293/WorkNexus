import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/dashboard_item_kind.dart';

part 'dashboard_work_item.freezed.dart';

/// One row of a "my work" list on the dashboard: a task, bug, story or todo
/// assigned to the user.
@freezed
abstract class DashboardWorkItem with _$DashboardWorkItem {
  const factory DashboardWorkItem({
    required DashboardItemKind kind,

    /// The ZenTao id (bugs, tasks and stories share number ranges).
    required String id,
    required String title,

    /// ZenTao status code (`active`, `doing`, `wait`…), lower-case.
    String? status,

    /// The server's own label for [status], when it sends one.
    String? statusLabel,

    /// ZenTao priority, 1 (highest) … 4.
    int? priority,
    DateTime? deadline,

    /// Where it lives: the execution, product or project name.
    String? context,
  }) = _DashboardWorkItem;
}
