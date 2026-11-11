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

  /// The chat, a place of its own on the rail rather than a tab of ZenTao,
  /// so going back to ZenTao lands on its tasks / bugs, not on the chat.
  const factory RailTarget.chat() = ChatTarget;

  /// The app's settings and connected accounts, at the foot of the rail
  /// rather than inside the dashboard.
  const factory RailTarget.settings() = SettingsTarget;
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
    @Default(SettingsSection.general) SettingsSection settingsSection,

    /// Last location per account — restored when its rail button is picked.
    @Default(<String, ToolLocation>{}) Map<String, ToolLocation> locations,
    @Default(false) bool notificationsOpen,
    TicketEditorRoute? editor,

    /// The detail slide-over of each place ([detailPlace]: the chat, an
    /// account's Bugs / Tasks / Docs…): the tickets opened there, oldest
    /// first. Each keeps its own, so going elsewhere and back finds the
    /// detail as it was left.
    @Default(<String, List<String>>{})
    Map<String, List<String>> ticketHistories,

    /// Whether the user explicitly navigated to the Workspace section.
    @Default(false) bool userSelectedWorkspace,

    /// The mini app shown in place of the rail's workspace / account view
    /// (null: none). Picking a place on the rail closes it.
    String? miniAppId,
  }) = _AppNavState;

  /// The place on screen that keeps a detail slide-over of its own: each
  /// account section (Bugs, Tasks, Docs…), the chat, each workspace page.
  String get detailPlace => switch (rail) {
    AccountTarget(:final accountId) =>
      'account:$accountId/${locations[accountId]?.section.value ?? ''}',
    WorkspaceTarget() => 'workspace:${workspaceSection.name}',
    ChatTarget() => 'chat',
    SettingsTarget() => 'settings',
  };

  /// The tickets opened in the detail slide-over of the place on screen,
  /// oldest first.
  List<String> get ticketHistory => ticketHistories[detailPlace] ?? const [];

  /// The ticket the detail slide-over shows; null when it is closed or the
  /// editor covers it.
  String? get openTicketId => editor == null ? ticketHistory.lastOrNull : null;

  /// Whether the detail slide-over has an earlier ticket to go back to.
  bool get canGoBack => openTicketId != null && ticketHistory.length > 1;

  ToolLocation? get currentLocation => switch (rail) {
    AccountTarget(:final accountId) => locations[accountId],
    WorkspaceTarget() || ChatTarget() || SettingsTarget() => null,
  };
}
