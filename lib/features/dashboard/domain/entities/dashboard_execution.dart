import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_execution.freezed.dart';

/// An unfinished execution (sprint) the user takes part in.
@freezed
abstract class DashboardExecution with _$DashboardExecution {
  const factory DashboardExecution({
    required String id,
    required String name,
    String? projectName,

    /// ZenTao status code (`wait`, `doing`, `suspended`…), lower-case.
    String? status,

    /// Completion, 0–100, when the server reports it.
    double? progress,
    DateTime? end,
  }) = _DashboardExecution;
}
