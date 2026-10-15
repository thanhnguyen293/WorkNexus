import 'package:freezed_annotation/freezed_annotation.dart';

import 'ticket_editor_route.dart';

part 'app_nav_state.freezed.dart';

/// The app's main destinations, picked from the left rail.
enum MainView { dashboard, chat, board, miniApp }

/// Where the app shell is: the main view, what covers it (settings, the
/// bug / task editor, the notifications panel) and the ticket detail
/// slide-over's history. Changed only through [AppNavController], which keeps
/// these consistent with one another.
@freezed
abstract class AppNavState with _$AppNavState {
  const AppNavState._();

  const factory AppNavState({
    // The app opens on chat.
    @Default(MainView.chat) MainView view,

    /// The mini app shown when [view] is [MainView.miniApp].
    String? miniAppId,
    @Default(false) bool settingsOpen,
    @Default(false) bool notificationsOpen,
    TicketEditorRoute? editor,

    /// Tickets opened in the detail slide-over, oldest first; the last one is
    /// showing. Kept (hidden) while the editor is open, so closing the editor
    /// returns to the ticket it was opened from.
    @Default(<String>[]) List<String> ticketHistory,
  }) = _AppNavState;

  /// The ticket the detail slide-over shows; null when it is closed or the
  /// editor covers it.
  String? get openTicketId => editor == null ? ticketHistory.lastOrNull : null;

  /// Whether the detail slide-over has an earlier ticket to go back to.
  bool get canGoBack => openTicketId != null && ticketHistory.length > 1;
}
