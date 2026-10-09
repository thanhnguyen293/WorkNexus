import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/ticket_editor_route.dart';

void main() {
  testWidgets('picking a main view closes an open bug / task editor', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
    ref
        .read(ticketEditorProvider.notifier)
        .open(const NewBugRoute(accountId: 'acc'));

    showBoardView(ref);

    expect(ref.read(ticketEditorProvider), isNull);
    expect(ref.read(mainViewProvider), MainView.board);

    ref
        .read(ticketEditorProvider.notifier)
        .open(const NewTaskRoute(accountId: 'acc'));
    showChatView(ref);

    expect(ref.read(ticketEditorProvider), isNull);
    expect(ref.read(mainViewProvider), MainView.chat);
  });

  testWidgets('opening the editor closes what would cover or hide it', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
    ref.read(notificationsPanelOpenProvider.notifier).state = true;
    ref.read(settingsOpenProvider.notifier).state = true;
    ref.read(openTicketIdProvider.notifier).open('t1');

    const route = NewBugRoute(accountId: 'acc');
    openTicketEditor(ref, route);

    expect(ref.read(notificationsPanelOpenProvider), isFalse);
    expect(ref.read(settingsOpenProvider), isFalse);
    expect(ref.read(openTicketIdProvider), isNull);
    expect(ref.read(ticketEditorProvider), route);
  });
}
