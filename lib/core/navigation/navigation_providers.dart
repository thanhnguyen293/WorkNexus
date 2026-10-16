import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../di/providers.dart';
import '../domain/entities/account.dart';
import '../domain/entities/workspace.dart';
import 'app_nav_controller.dart';
import 'app_nav_state.dart';
import 'ticket_editor_route.dart';

export 'app_nav_controller.dart';
export 'app_nav_state.dart';

/// App-shell navigation state, shared across features so they coordinate
/// through it (rule 10.2) instead of importing one another's presentation
/// layer. [appNavProvider] owns it; the providers below are read-only slices
/// so a widget rebuilds only for the part it shows.
final appNavProvider = NotifierProvider<AppNavController, AppNavState>(
  AppNavController.new,
);

/// The mini app picked on the rail (null: none), even while the editor covers
/// it.
final openMiniAppIdProvider = Provider<String?>(
  (ref) => ref.watch(appNavProvider.select((s) => s.miniAppId)),
);

/// Whether a mini app is the view beside the rail (picked, and not covered by
/// the editor).
final miniAppOnScreenProvider = Provider<bool>(
  (ref) => ref.watch(
    appNavProvider.select((s) => s.miniAppId != null && s.editor == null),
  ),
);

/// The ticket in the detail slide-over (null = closed).
final openTicketIdProvider = Provider<String?>(
  (ref) => ref.watch(appNavProvider.select((s) => s.openTicketId)),
);

/// The rail destination (workspace or specific account).
final railTargetProvider = Provider<RailTarget>(
  (ref) => ref.watch(appNavProvider.select((s) => s.rail)),
);

/// The active workspace section when rail is workspace.
final workspaceSectionProvider = Provider<WorkspaceSection>(
  (ref) => ref.watch(appNavProvider.select((s) => s.workspaceSection)),
);

/// The current tool location when rail is an account (null otherwise).
final currentToolLocationProvider = Provider<ToolLocation?>(
  (ref) => ref.watch(appNavProvider.select((s) => s.currentLocation)),
);

/// Whether the detail slide-over has an earlier ticket to go back to.
final ticketCanGoBackProvider = Provider<bool>(
  (ref) => ref.watch(appNavProvider.select((s) => s.canGoBack)),
);

/// Whether the ZenTao chat view is the active section.
final chatOpenProvider = Provider<bool>(
  (ref) =>
      ref.watch(
        appNavProvider.select((s) => s.currentLocation?.section.value),
      ) ==
      'zentao.chat',
);

/// The open bug / task editor, which replaces the board and sidebar; null when
/// none is open.
final ticketEditorProvider = Provider<TicketEditorRoute?>(
  (ref) => ref.watch(appNavProvider.select((s) => s.editor)),
);

/// Whether the notifications panel is open beside the rail (over the current
/// view, which stays as it is).
final notificationsPanelOpenProvider = Provider<bool>(
  (ref) => ref.watch(appNavProvider.select((s) => s.notificationsOpen)),
);

/// Whether the Quick Settings panel is docked open at the window's right.
final quickSettingsOpenProvider = StateProvider<bool>((ref) => false);

/// Hidden developer log panel, opened from the title-bar settings trigger.
final talkerDebugOpenProvider = StateProvider<bool>((ref) => false);

/// The workspace the user joined. Null means default to the first workspace.
///
/// Holds only the user's choice and watches nothing: deriving it from
/// [workspacesProvider] would recreate it — dropping the choice — every time
/// any workspace changes. Read [activeWorkspaceProvider] for the workspace in
/// effect, which falls back to the first one when the choice is gone.
final activeWorkspaceIdProvider = StateProvider<String?>((ref) => null);

/// The currently active workspace entity.
final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  final activeId = ref.watch(activeWorkspaceIdProvider);
  final workspaces = ref.watch(workspacesProvider).asData?.value ?? const [];
  if (workspaces.isEmpty) return null;
  if (activeId == null) return workspaces.first;
  for (final w in workspaces) {
    if (w.id == activeId) return w;
  }
  return workspaces.first;
});

/// The sorted accounts belonging to the active workspace.
final sortedActiveAccountsProvider = Provider<List<Account>>((ref) {
  final activeWsId = ref.watch(activeWorkspaceProvider)?.id;
  final allAccounts = ref.watch(accountsProvider).asData?.value ?? const [];
  final activeAccounts = allAccounts
      .where((a) => activeWsId == null || a.workspaceId == activeWsId)
      .toList();
  return Account.sort(activeAccounts);
});
