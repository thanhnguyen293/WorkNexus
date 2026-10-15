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

  Map<String, dynamic> toJson() => switch (this) {
    WorkspaceTarget() => {'kind': 'workspace'},
    AccountTarget(:final accountId) => {
      'kind': 'account',
      'accountId': accountId,
    },
  };

  factory RailTarget.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind == 'account') {
      final id = json['accountId'];
      if (id is String && id.isNotEmpty) {
        return RailTarget.account(id);
      }
    }
    return const RailTarget.workspace();
  }
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

  Map<String, dynamic> toJson() => {
    'section': section.value,
    if (scopeId != null) 'scopeId': scopeId,
    'quickScope': quickScope.name,
    'viewModes': viewModes.map((k, v) => MapEntry(k.value, v.value)),
    'recentScopeIds': recentScopeIds,
  };

  factory ToolLocation.fromJson(Map<String, dynamic> json) {
    final sec = json['section'];
    if (sec is! String || sec.isEmpty) {
      throw const FormatException('Invalid or missing section');
    }
    final vmRaw = json['viewModes'];
    final vms = <SectionId, ViewModeId>{};
    if (vmRaw is Map) {
      for (final e in vmRaw.entries) {
        if (e.key is String && e.value is String) {
          vms[SectionId(e.key as String)] = ViewModeId(e.value as String);
        }
      }
    }
    final recentsRaw = json['recentScopeIds'];
    final recents = <String>[];
    if (recentsRaw is List) {
      for (final r in recentsRaw) {
        if (r is String && r.isNotEmpty && !recents.contains(r)) {
          recents.add(r);
        }
      }
    }
    final qsRaw = json['quickScope'] as String?;
    final qs = QuickScope.values.firstWhere(
      (e) => e.name == qsRaw,
      orElse: () => QuickScope.all,
    );
    return ToolLocation(
      section: SectionId(sec),
      scopeId: json['scopeId'] as String?,
      quickScope: qs,
      viewModes: vms,
      recentScopeIds: recents.take(5).toList(),
    );
  }
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

/// Serialized payload for `nav.last_location.v1` in `Settings`.
class NavLocationPayload {
  const NavLocationPayload({
    this.rail = const RailTarget.workspace(),
    this.workspaceSection = WorkspaceSection.overview,
    this.locations = const <String, ToolLocation>{},
    this.version = kNavLocationVersion,
  });

  static const int kNavLocationVersion = 1;

  final int version;
  final RailTarget rail;
  final WorkspaceSection workspaceSection;
  final Map<String, ToolLocation> locations;

  Map<String, dynamic> toJson() => {
    'version': version,
    'rail': rail.toJson(),
    'workspaceSection': workspaceSection.name,
    'locations': locations.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory NavLocationPayload.fromJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != kNavLocationVersion) {
      return const NavLocationPayload();
    }
    try {
      final railRaw = json['rail'];
      final rail = railRaw is Map<String, dynamic>
          ? RailTarget.fromJson(railRaw)
          : const RailTarget.workspace();
      final wsSecName = json['workspaceSection'] as String?;
      final wsSec = WorkspaceSection.values.firstWhere(
        (e) => e.name == wsSecName,
        orElse: () => WorkspaceSection.overview,
      );
      final locsRaw = json['locations'];
      final locs = <String, ToolLocation>{};
      if (locsRaw is Map) {
        for (final e in locsRaw.entries) {
          if (e.key is String && e.value is Map<String, dynamic>) {
            try {
              locs[e.key as String] = ToolLocation.fromJson(
                e.value as Map<String, dynamic>,
              );
            } catch (_) {
              // skip malformed entry
            }
          }
        }
      }
      return NavLocationPayload(
        rail: rail,
        workspaceSection: wsSec,
        locations: locs,
        version: v as int,
      );
    } catch (_) {
      return const NavLocationPayload();
    }
  }
}
