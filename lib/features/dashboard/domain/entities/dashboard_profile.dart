import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_profile.freezed.dart';

/// The signed-in ZenTao user, as shown in the dashboard header.
@freezed
abstract class DashboardProfile with _$DashboardProfile {
  const factory DashboardProfile({
    required String account,
    required String realname,

    /// The role's display name (e.g. `Developer`).
    String? role,
    String? email,
    DateTime? lastLogin,
  }) = _DashboardProfile;
}
