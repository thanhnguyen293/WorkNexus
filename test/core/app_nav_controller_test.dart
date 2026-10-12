import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/ticket_editor_route.dart';

void main() {
  late ProviderContainer container;
  AppNavController nav() => container.read(appNavProvider.notifier);
  AppNavState state() => container.read(appNavProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  const editRoute = EditBugRoute(accountId: 'acc', bugId: '7', ticketId: 't1');

  group('show', () {
    test('closes settings, notifications, the editor and the detail', () {
      nav()
        ..openTicket('t1')
        ..openEditor(const NewBugRoute(accountId: 'acc'))
        ..openSettings()
        ..toggleNotifications();

      nav().show(MainView.board);

      expect(state(), const AppNavState(view: MainView.board));
    });
  });

  group('editor', () {
    test('opening closes settings and notifications, hides the detail', () {
      nav()
        ..openTicket('t1')
        ..toggleNotifications()
        ..openEditor(const NewBugRoute(accountId: 'acc'));
      nav().openSettings();

      nav().openEditor(editRoute);

      expect(state().settingsOpen, isFalse);
      expect(state().notificationsOpen, isFalse);
      expect(state().editor, editRoute);
      expect(container.read(openTicketIdProvider), isNull);
    });

    test('cancelling returns to the ticket it was opened from', () {
      nav()
        ..openTicket('t1')
        ..openEditor(editRoute);

      nav().closeEditor();

      expect(container.read(openTicketIdProvider), 't1');
    });

    test('saving an edit reopens the ticket without a duplicate entry', () {
      nav()
        ..openTicket('t1')
        ..openEditor(editRoute)
        ..closeEditor()
        ..openTicket('t1');

      expect(state().ticketHistory, ['t1']);
      expect(container.read(ticketCanGoBackProvider), isFalse);
    });

    test('saving a new bug from a ticket can go back to that ticket', () {
      nav()
        ..openTicket('t1')
        ..openEditor(const NewBugRoute(accountId: 'acc', copyOf: '7'))
        ..closeEditor()
        ..openTicket('t2');

      expect(container.read(openTicketIdProvider), 't2');
      nav().back();
      expect(container.read(openTicketIdProvider), 't1');
    });
  });

  group('ticket history', () {
    test('a ticket opened from the detail goes back to the previous one', () {
      nav()
        ..openTicket('parent')
        ..openTicket('child');

      expect(container.read(ticketCanGoBackProvider), isTrue);
      nav().back();

      expect(container.read(openTicketIdProvider), 'parent');
      expect(container.read(ticketCanGoBackProvider), isFalse);
    });

    test('back on the first ticket keeps it open', () {
      nav()
        ..openTicket('t1')
        ..back();

      expect(container.read(openTicketIdProvider), 't1');
    });

    test('closing forgets the history; the next open starts fresh', () {
      nav()
        ..openTicket('t1')
        ..openTicket('t2')
        ..closeTicket()
        ..openTicket('t3');

      expect(state().ticketHistory, ['t3']);
    });
  });

  group('settings', () {
    test('opening closes the detail and the notifications panel', () {
      nav()
        ..openTicket('t1')
        ..toggleNotifications()
        ..openSettings();

      expect(container.read(settingsOpenProvider), isTrue);
      expect(container.read(openTicketIdProvider), isNull);
      expect(container.read(notificationsPanelOpenProvider), isFalse);
    });

    test('opened over the editor, closing it returns to the editor', () {
      nav()
        ..openTicket('t1')
        ..openEditor(editRoute)
        ..toggleSettings()
        ..toggleSettings();

      expect(state().editor, editRoute);
      nav().closeEditor();
      expect(container.read(openTicketIdProvider), 't1');
    });
  });

  test('the rail marks no view while settings or the editor covers it', () {
    nav().show(MainView.board);
    expect(container.read(selectedMainViewProvider), MainView.board);

    nav().openEditor(editRoute);
    expect(container.read(selectedMainViewProvider), isNull);

    nav()
      ..closeEditor()
      ..openSettings();
    expect(container.read(selectedMainViewProvider), isNull);
  });
}
