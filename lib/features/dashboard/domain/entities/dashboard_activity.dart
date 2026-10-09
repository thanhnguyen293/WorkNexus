import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_activity.freezed.dart';

/// One entry of the recent-activity feed (ZenTao "dynamic").
@freezed
abstract class DashboardActivity with _$DashboardActivity {
  const factory DashboardActivity({
    required String id,
    required String actor,

    /// The server's label for what happened (e.g. `resolved`), falling back to
    /// the raw action code.
    required String action,

    /// ZenTao `objectType` code (`bug`, `task`, `story`, `project`…).
    required String objectType,
    required String objectId,
    String? objectName,
    DateTime? date,
  }) = _DashboardActivity;
}
