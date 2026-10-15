import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/ticket_editor_route.dart';
import 'package:work_nexus/core/tools/tool_module.dart';

void main() {
  late ProviderContainer container;
  AppNavController nav() => container.read(appNavProvider.notifier);
  AppNavState state() => container.read(appNavProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  const editRoute = EditBugRoute(accountId: 'acc', bugId: '7', ticketId: 't1');

  group('workspace and account navigation', () {
    test(
      'selectWorkspaceSection updates rail target and workspace section',
      () {
        nav().selectAccount('acc_1');
        expect(
          container.read(railTargetProvider),
          const RailTarget.account('acc_1'),
        );

        nav().selectWorkspaceSection(WorkspaceSection.integrations);

        expect(
          container.read(railTargetProvider),
          const RailTarget.workspace(),
        );
        expect(
          container.read(workspaceSectionProvider),
          WorkspaceSection.integrations,
        );
      },
    );

    test(
      'selectAccount switches to account target and seeds default section',
      () {
        nav().selectAccount('acc_1');

        expect(
          container.read(railTargetProvider),
          const RailTarget.account('acc_1'),
        );
        expect(
          container.read(currentToolLocationProvider)?.section,
          const SectionId('default'),
        );
      },
    );

    test(
      'selectSection updates section and resets scope when scope kinds differ',
      () {
        nav().selectAccount('acc_1');
        nav().selectScope('proj_1');
        expect(container.read(currentToolLocationProvider)?.scopeId, 'proj_1');

        nav().selectSection(
          const SectionId('bugs'),
          oldScopeKind: ScopeKind.project,
          newScopeKind: ScopeKind.product,
        );

        expect(
          container.read(currentToolLocationProvider)?.section,
          const SectionId('bugs'),
        );
        expect(container.read(currentToolLocationProvider)?.scopeId, isNull);
      },
    );

    test('selectScope records recents newest first capped at 5', () {
      nav().selectAccount('acc_1');

      nav().selectScope('s1');
      nav().selectScope('s2');
      nav().selectScope('s3');
      nav().selectScope('s4');
      nav().selectScope('s5');
      nav().selectScope('s6');

      final loc = container.read(currentToolLocationProvider)!;
      expect(loc.scopeId, 's6');
      expect(loc.recentScopeIds, ['s6', 's5', 's4', 's3', 's2']);
    });
  });

  group('notifications', () {
    test('toggleNotifications opens and closes the notifications panel', () {
      expect(container.read(notificationsPanelOpenProvider), isFalse);

      nav().toggleNotifications();
      expect(container.read(notificationsPanelOpenProvider), isTrue);

      nav().toggleNotifications();
      expect(container.read(notificationsPanelOpenProvider), isFalse);
    });

    test('closeNotifications ensures notifications are closed', () {
      nav().toggleNotifications();
      expect(container.read(notificationsPanelOpenProvider), isTrue);

      nav().closeNotifications();
      expect(container.read(notificationsPanelOpenProvider), isFalse);
    });
  });

  group('editor', () {
    test('opening closes notifications and hides the detail', () {
      nav()
        ..openTicket('t1')
        ..toggleNotifications()
        ..openEditor(editRoute);

      expect(state().notificationsOpen, isFalse);
      expect(state().editor, editRoute);
      expect(container.read(ticketEditorProvider), editRoute);
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
}
