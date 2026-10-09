import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/zentao_ticket_service.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/notification_body.dart';
import 'package:work_nexus/features/chat/presentation/widgets/zentao_ticket_card.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockService extends Mock implements ZenTaoTicketService {}

const _url = 'https://zentao.oasoft.xyz:4433/zentao/bug-view-123.html';

const _bug = Ticket(
  id: 'zt:123',
  accountId: 'zt',
  projectId: 'zt:bug',
  providerType: ProviderType.zentao,
  externalKey: '123',
  externalType: 'Bug',
  title: 'Login button does nothing',
  body: '',
  priority: Priority.high,
  status: UnifiedStatus.inprogress,
  providerStatus: 'active',
  sourceHash: '',
  assignee: 'Thanh',
  url: _url,
);

void main() {
  late _MockService service;

  setUp(() => service = _MockService());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Stream<List<Ticket>> tickets, {
    Widget body = const ZenTaoTicketCard(url: _url),
  }) async {
    final container = ProviderContainer(
      overrides: [
        zenTaoTicketServiceProvider.overrideWithValue(service),
        ticketsProvider.overrideWith((ref) => tickets),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> end(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('a synced ticket shows at once, without asking ZenTao', (
    tester,
  ) async {
    final container = await pump(tester, Stream.value([_bug]));

    expect(find.text('Login button does nothing'), findsOneWidget);
    expect(find.textContaining('Bug #123', findRichText: true), findsOneWidget);
    expect(find.textContaining('Thanh', findRichText: true), findsOneWidget);
    verifyNever(
      () => service.fetchZenTaoTicket(
        host: any(named: 'host'),
        type: any(named: 'type'),
        id: any(named: 'id'),
      ),
    );
    await end(tester, container);
  });

  testWidgets('an unsynced ticket is fetched and then shown', (tester) async {
    final tickets = StreamController<List<Ticket>>()..add(const []);
    addTearDown(tickets.close);
    when(
      () => service.fetchZenTaoTicket(
        host: any(named: 'host'),
        type: any(named: 'type'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async {
      tickets.add(const [_bug]);
      return const Ok('zt:123');
    });

    final container = await pump(tester, tickets.stream);

    verify(
      () => service.fetchZenTaoTicket(
        host: 'zentao.oasoft.xyz',
        type: 'bug',
        id: '123',
      ),
    ).called(1);
    expect(find.text('Login button does nothing'), findsOneWidget);
    await end(tester, container);
  });

  testWidgets('a bot notification about a ticket shows it as a card', (
    tester,
  ) async {
    final container = await pump(
      tester,
      Stream.value([_bug]),
      body: const NotificationBody(
        accountId: 'acc',
        notification: NotificationContent(
          sender: 'ZenTao',
          title: 'JunNg assigned 1 Bug',
          subtitle: 'VN_Socialfi',
          text: '#123 Login button does nothing',
          markdown: false,
          url: _url,
        ),
      ),
    );

    expect(find.text('ZenTao · VN_Socialfi'), findsOneWidget);
    expect(find.text('JunNg assigned 1 Bug'), findsOneWidget);
    // The card's live title, not the notification's text repeated.
    expect(find.text('Login button does nothing'), findsOneWidget);
    expect(find.textContaining('Thanh', findRichText: true), findsOneWidget);
    expect(
      find.text('View details'),
      findsNothing,
      reason: 'the card opens it',
    );
    await end(tester, container);
  });

  testWidgets('a ticket that cannot be loaded still shows its name', (
    tester,
  ) async {
    when(
      () => service.fetchZenTaoTicket(
        host: any(named: 'host'),
        type: any(named: 'type'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => const Err(NotFoundFailure('no account')));

    final container = await pump(
      tester,
      Stream.value(const []),
      body: const ZenTaoTicketCard(url: _url, fallbackTitle: 'Crash on launch'),
    );

    expect(find.text('Crash on launch'), findsOneWidget);
    await end(tester, container);
  });
}
