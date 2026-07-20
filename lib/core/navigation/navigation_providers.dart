import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../di/providers.dart';

/// App-shell view state shared across features: which ticket's detail overlay is
/// open, and whether the settings view replaces the board. Lives in the shared
/// kernel so features coordinate through it (rule 10.2) instead of importing one
/// another's presentation layer.

/// The currently open ticket in the detail slide-over (null = closed).
class OpenTicketController extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String id) => state = id;
  void close() => state = null;
}

final openTicketIdProvider = NotifierProvider<OpenTicketController, String?>(
  OpenTicketController.new,
);

/// Whether the Settings / Integrations view is showing (replaces the board).
final settingsOpenProvider = StateProvider<bool>((ref) => false);

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

/// Hidden developer log panel, opened from the title-bar settings trigger.
final talkerDebugOpenProvider = StateProvider<bool>((ref) => false);
