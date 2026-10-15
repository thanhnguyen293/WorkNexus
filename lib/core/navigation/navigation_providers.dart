import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../di/providers.dart';
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

/// The ticket in the detail slide-over (null = closed).
final openTicketIdProvider = Provider<String?>(
  (ref) => ref.watch(appNavProvider.select((s) => s.openTicketId)),
);

/// Whether the detail slide-over has an earlier ticket to go back to.
final ticketCanGoBackProvider = Provider<bool>(
  (ref) => ref.watch(appNavProvider.select((s) => s.canGoBack)),
);

/// Whether the Settings / Integrations view was opened (replaces the board).
final settingsOpenProvider = Provider<bool>(
  (ref) => ref.watch(appNavProvider.select((s) => s.settingsOpen)),
);

/// Which main view fills the window (settings still wins when open).
final mainViewProvider = Provider<MainView>(
  (ref) => ref.watch(appNavProvider.select((s) => s.view)),
);

/// The mini app on show (null unless [MainView.miniApp] is the main view).
final openMiniAppIdProvider = Provider<String?>(
  (ref) => ref.watch(appNavProvider.select((s) => s.miniAppId)),
);

/// Whether the ZenTao chat view is the main view.
final chatOpenProvider = Provider<bool>(
  (ref) => ref.watch(mainViewProvider) == MainView.chat,
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

/// First-run onboarding state: when there is no workspace or no connected
/// provider account yet, the app should open Integrations instead of an empty
/// board.
final needsInitialIntegrationsProvider = Provider<bool>((ref) {
  final workspaces = ref.watch(workspacesProvider);
  final accounts = ref.watch(accountsProvider);
  final noWorkspaces = workspaces.maybeWhen(
    data: (items) => items.isEmpty,
    orElse: () => false,
  );
  final noAccounts = accounts.maybeWhen(
    data: (items) => items.isEmpty,
    orElse: () => false,
  );
  return noWorkspaces || noAccounts;
});

/// Effective Integrations visibility. Manual opens still use
/// [settingsOpenProvider], while first-run empty state forces the page open.
final integrationsVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsOpenProvider) ||
      ref.watch(needsInitialIntegrationsProvider),
);

/// The main view the rail marks as current: none while settings or the bug /
/// task editor covers it.
final selectedMainViewProvider = Provider<MainView?>((ref) {
  if (ref.watch(integrationsVisibleProvider)) return null;
  if (ref.watch(ticketEditorProvider) != null) return null;
  return ref.watch(mainViewProvider);
});

/// Hidden developer log panel, opened from the title-bar settings trigger.
final talkerDebugOpenProvider = StateProvider<bool>((ref) => false);
