import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/account.dart';
import '../domain/value_objects/provider_type.dart';
import '../tools/tool_module.dart';
import 'app_nav_state.dart';
import 'ticket_editor_route.dart';

/// The one place that moves the app shell between views and overlays, so what
/// must close when something opens is decided here rather than by each caller.
class AppNavController extends Notifier<AppNavState> {
  @override
  AppNavState build() => const AppNavState();

  // ---- Workspace & Account Selection ----

  /// Switches the rail to the workspace level and sets the active workspace section.
  void selectWorkspaceSection(WorkspaceSection section) {
    // Going somewhere from the rail leaves the editor, which covers the
    // whole area beside the rail — or the click would look dead.
    state = state.copyWith(
      rail: const RailTarget.workspace(),
      workspaceSection: section,
      userSelectedWorkspace: true,
      editor: null,
      miniAppId: null,
    );
  }

  /// Switches the rail to an account target. If no location has been stored for
  /// this account yet (or [activateFirstFeature] is true), it is seeded with
  /// the module's first section/default section.
  void selectAccount(
    String id, {
    ToolModule? module,
    bool activateFirstFeature = false,
  }) {
    final existingLoc = state.locations[id];
    final defaultSec = (module != null && module.sections.isNotEmpty)
        ? module.sections.first.id
        : (module?.defaultSection ?? const SectionId('default'));
    final locations = (existingLoc == null || activateFirstFeature)
        ? <String, ToolLocation>{
            ...state.locations,
            id: ToolLocation(section: defaultSec),
          }
        : state.locations;

    state = state.copyWith(
      rail: RailTarget.account(id),
      locations: locations,
      userSelectedWorkspace: false,
      editor: null,
      miniAppId: null,
    );
  }

  /// Automatically selects the first app in [accounts] and activates its first
  /// feature (section), unless the user has explicitly chosen the workspace section.
  void selectDefaultAppIfApplicable({
    required List<Account> accounts,
    required Map<ProviderType, ToolModule> registry,
    bool force = false,
  }) {
    if (accounts.isEmpty) return;

    if (!force && state.userSelectedWorkspace) {
      return;
    }

    if (!force) {
      if (state.rail case AccountTarget(:final accountId)) {
        if (accounts.any((a) => a.id == accountId)) {
          return;
        }
      }
    }

    final sorted = Account.sort(accounts);
    final firstAccount = sorted.first;
    final module = registry[firstAccount.providerType];

    selectAccount(firstAccount.id, module: module, activateFirstFeature: true);
  }

  /// Called when the user switches to a workspace in the workspace switcher.
  /// Resets [userSelectedWorkspace] and activates the first app & first feature
  /// of the new workspace.
  void onWorkspaceSwitched({
    required List<Account> newAccounts,
    required Map<ProviderType, ToolModule> registry,
  }) {
    state = state.copyWith(userSelectedWorkspace: false);
    if (newAccounts.isEmpty) {
      // Counts as choosing the workspace: until the new workspace's (empty)
      // account list arrives, the default selection must not pick an
      // account of the workspace being left.
      state = state.copyWith(
        rail: const RailTarget.workspace(),
        workspaceSection: WorkspaceSection.overview,
        userSelectedWorkspace: true,
      );
    } else {
      selectDefaultAppIfApplicable(
        accounts: newAccounts,
        registry: registry,
        force: true,
      );
    }
  }

  /// Changes the active section under the current account.
  /// If the new and old sections share the same [ScopeKind], the selected scope
  /// is preserved; otherwise it is reset to null ("All").
  /// The tool's [sections] (or its [module]'s) tell the scope kinds apart.
  void selectSection(
    SectionId section, {
    ToolModule? module,
    List<ToolSection>? sections,
    ScopeKind? newScopeKind,
    ScopeKind? oldScopeKind,
  }) {
    if (state.rail case AccountTarget(:final accountId)) {
      final cur = state.locations[accountId] ?? ToolLocation(section: section);

      bool keepScope = false;
      final known = sections ?? module?.sections;
      if (known != null) {
        final oldSec = known.where((s) => s.id == cur.section).firstOrNull;
        final newSec = known.where((s) => s.id == section).firstOrNull;
        keepScope =
            oldSec != null &&
            newSec != null &&
            oldSec.scopeKind == newSec.scopeKind;
      } else if (newScopeKind != null) {
        keepScope = newScopeKind == oldScopeKind;
      }

      final updated = cur.copyWith(
        section: section,
        scopeId: keepScope ? cur.scopeId : null,
      );
      state = state.copyWith(
        locations: <String, ToolLocation>{
          ...state.locations,
          accountId: updated,
        },
      );
    }
  }

  /// Sets the selected scope for the current account's active section and
  /// updates the recent scope history (capped at 5, deduplicated, newest first).
  void selectScope(String? scopeId) {
    if (state.rail case AccountTarget(:final accountId)) {
      final cur = state.locations[accountId];
      if (cur == null) return;

      final recents = (scopeId != null && scopeId.isNotEmpty)
          ? [
              scopeId,
              ...cur.recentScopeIds.where((e) => e != scopeId),
            ].take(5).toList()
          : cur.recentScopeIds;

      final updated = cur.copyWith(scopeId: scopeId, recentScopeIds: recents);
      state = state.copyWith(
        locations: <String, ToolLocation>{
          ...state.locations,
          accountId: updated,
        },
      );
    }
  }

  /// Sets the quick scope filter (all, assigned to me, review requested) for
  /// the active tool location.
  void setQuickScope(QuickScope quickScope) {
    if (state.rail case AccountTarget(:final accountId)) {
      final cur = state.locations[accountId];
      if (cur == null) return;
      final updated = cur.copyWith(quickScope: quickScope);
      state = state.copyWith(
        locations: <String, ToolLocation>{
          ...state.locations,
          accountId: updated,
        },
      );
    }
  }

  /// Sets the remembered view mode for the active section (e.g. tasks → kanban).
  void setViewMode(ViewModeId viewMode) {
    if (state.rail case AccountTarget(:final accountId)) {
      final cur = state.locations[accountId];
      if (cur == null) return;
      final viewModes = Map<SectionId, ViewModeId>.from(cur.viewModes)
        ..[cur.section] = viewMode;
      final updated = cur.copyWith(viewModes: viewModes);
      state = state.copyWith(
        locations: <String, ToolLocation>{
          ...state.locations,
          accountId: updated,
        },
      );
    }
  }

  /// Called when the workspace switches or its accounts change.
  /// Falls back to Workspace › Overview if the active account is no longer in the workspace.
  void onWorkspaceChanged(Set<String> accountIds) {
    if (state.rail case AccountTarget(:final accountId)) {
      if (!accountIds.contains(accountId)) {
        state = state.copyWith(
          rail: const RailTarget.workspace(),
          workspaceSection: WorkspaceSection.overview,
        );
      }
    }
  }

  /// Handles removal of an account, falling back to Overview if it was active.
  void onAccountRemoved(String id) {
    final nextLocations = Map<String, ToolLocation>.from(state.locations)
      ..remove(id);
    if (state.rail case AccountTarget(:final accountId) when accountId == id) {
      state = state.copyWith(
        rail: const RailTarget.workspace(),
        workspaceSection: WorkspaceSection.overview,
        locations: nextLocations,
      );
    } else {
      state = state.copyWith(locations: nextLocations);
    }
  }

  /// Shows the mini app [id] beside the rail, closing what covers it: the
  /// editor, the notifications panel and the ticket detail.
  void showMiniApp(String id) => state = state.copyWith(
    miniAppId: id,
    editor: null,
    notificationsOpen: false,
    ticketHistory: const [],
  );

  /// Leaves the mini app for the rail's workspace / account view.
  void closeMiniApp() => state = state.copyWith(miniAppId: null);

  void toggleNotifications() =>
      state = state.copyWith(notificationsOpen: !state.notificationsOpen);

  void closeNotifications() => state = state.copyWith(notificationsOpen: false);

  /// Shows ticket [id] in the detail slide-over. Opened from the detail itself
  /// (a parent / subtask or a linked ticket), it goes on top of the history so
  /// [back] returns to the ticket it was opened from.
  void openTicket(String id) {
    final history = state.openTicketId == null
        ? const <String>[]
        : state.ticketHistory;
    if (history.lastOrNull == id) {
      state = state.copyWith(ticketHistory: history);
      return;
    }
    state = state.copyWith(ticketHistory: [...history, id]);
  }

  /// Returns the detail slide-over to the previous ticket; no-op without one.
  void back() {
    if (!state.canGoBack) return;
    final history = state.ticketHistory;
    state = state.copyWith(
      ticketHistory: history.sublist(0, history.length - 1),
    );
  }

  /// Closes the detail slide-over and forgets its history.
  void closeTicket() => state = state.copyWith(ticketHistory: const []);

  /// Opens the bug / task editor on [route]. It takes the whole area beside
  /// the rail, so the notifications panel closes; the ticket detail hides until
  /// the editor closes.
  void openEditor(TicketEditorRoute route) =>
      state = state.copyWith(editor: route, notificationsOpen: false);

  /// Closes the editor, back to the ticket detail it was opened from, if any.
  void closeEditor() => state = state.copyWith(editor: null);
}
