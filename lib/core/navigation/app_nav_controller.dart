import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_nav_state.dart';
import 'ticket_editor_route.dart';

/// The one place that moves the app shell between views and overlays, so what
/// must close when something opens is decided here rather than by each caller.
class AppNavController extends Notifier<AppNavState> {
  @override
  AppNavState build() => const AppNavState();

  /// Shows [view], closing everything over it: settings, the notifications
  /// panel, the editor and the ticket detail.
  void show(MainView view) => state = AppNavState(view: view);

  /// Shows the mini app [id], closing everything over it like [show].
  void showMiniApp(String id) =>
      state = AppNavState(view: MainView.miniApp, miniAppId: id);

  void toggleSettings() =>
      state.settingsOpen ? closeSettings() : openSettings();

  /// Opens settings over the main view. An open editor stays (hidden behind
  /// settings, with the ticket it came from); an open ticket detail closes.
  void openSettings() => state = state.copyWith(
    settingsOpen: true,
    notificationsOpen: false,
    ticketHistory: state.editor == null ? const [] : state.ticketHistory,
  );

  void closeSettings() => state = state.copyWith(settingsOpen: false);

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
  /// the rail, so settings and the notifications panel close; the ticket
  /// detail hides until the editor closes.
  void openEditor(TicketEditorRoute route) => state = state.copyWith(
    editor: route,
    settingsOpen: false,
    notificationsOpen: false,
  );

  /// Closes the editor, back to the ticket detail it was opened from, if any.
  void closeEditor() => state = state.copyWith(editor: null);
}
