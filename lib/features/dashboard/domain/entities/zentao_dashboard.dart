import 'package:freezed_annotation/freezed_annotation.dart';

import 'dashboard_activity.dart';
import 'dashboard_execution.dart';
import 'dashboard_profile.dart';
import 'dashboard_work_item.dart';

part 'zentao_dashboard.freezed.dart';

/// A ZenTao account's personal overview: who the user is, what is assigned to
/// them, the sprints they are in and what happened recently.
///
/// Each list holds only the first few items; the matching `*Total` is the full
/// count on the server.
@freezed
abstract class ZenTaoDashboard with _$ZenTaoDashboard {
  const factory ZenTaoDashboard({
    required String accountId,
    required DashboardProfile profile,

    /// When this snapshot was fetched from the server.
    required DateTime fetchedAt,
    @Default(<DashboardWorkItem>[]) List<DashboardWorkItem> tasks,
    @Default(0) int taskTotal,
    @Default(<DashboardWorkItem>[]) List<DashboardWorkItem> bugs,
    @Default(0) int bugTotal,
    @Default(<DashboardWorkItem>[]) List<DashboardWorkItem> stories,
    @Default(0) int storyTotal,
    @Default(<DashboardWorkItem>[]) List<DashboardWorkItem> todos,
    @Default(0) int todoTotal,
    @Default(<DashboardExecution>[]) List<DashboardExecution> executions,
    @Default(0) int executionTotal,
    @Default(<DashboardActivity>[]) List<DashboardActivity> activities,

    /// Contribution counters; null when the server did not report them.
    int? projectTotal,
    int? productTotal,
    int? docTotal,
  }) = _ZenTaoDashboard;
}
