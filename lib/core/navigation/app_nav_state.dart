import 'package:freezed_annotation/freezed_annotation.dart';

import 'nav_ids.dart';
import 'ticket_editor_route.dart';

export 'nav_ids.dart';

part 'app_nav_state.freezed.dart';

@freezed
sealed class RailTarget with _$RailTarget {
  const RailTarget._();

  const factory RailTarget.workspace() = WorkspaceTarget;
  const factory RailTarget.account(String accountId) = AccountTarget;
}

@freezed
abstract class ToolLocation with _$ToolLocation {
  const ToolLocation._();

  const factory ToolLocation({
    required SectionId section,
    String? scopeId, // null = "All"
    @Default(QuickScope.all) QuickScope quickScope,

    /// Remembered view mode per section, e.g. tasks → kanban.
    @Default(<SectionId, ViewModeId>{}) Map<SectionId, ViewModeId> viewModes,
    @Default(<String>[]) List<String> recentScopeIds, // max 5, newest first
  }) = _ToolLocation;
}

/// Where the app shell is: the workspace or account target, section, and locations,
/// alongside legacy views for backwards compatibility.
@freezed
abstract class AppNavState with _$AppNavState {
  const AppNavState._();

  const factory AppNavState({
    @Default(RailTarget.workspace()) RailTarget rail,
    @Default(WorkspaceSection.overview) WorkspaceSection workspaceSection,

    /// Last location per account — restored when its rail button is picked.
    @Default(<String, ToolLocation>{}) Map<String, ToolLocation> locations,
    @Default(false) bool notificationsOpen,
    TicketEditorRoute? editor,

    /// Tickets opened in the detail slide-over, oldest first.
    @Default(<String>[]) List<String> ticketHistory,

    /// Whether the user explicitly navigated to the Workspace section.
    @Default(false) bool userSelectedWorkspace,

    /// The mini app shown in place of the rail's workspace / account view
    /// (null: none). Picking a place on the rail closes it.
    String? miniAppId,
  }) = _AppNavState;

  /// The ticket the detail slide-over shows; null when it is closed or the
  /// editor covers it.
  String? get openTicketId => editor == null ? ticketHistory.lastOrNull : null;

  /// Whether the detail slide-over has an earlier ticket to go back to.
  bool get canGoBack => openTicketId != null && ticketHistory.length > 1;

  ToolLocation? get currentLocation => switch (rail) {
    AccountTarget(:final accountId) => locations[accountId],
    WorkspaceTarget() => null,
  };
}
