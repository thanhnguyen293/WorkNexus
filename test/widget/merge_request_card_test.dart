import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/merge_request_link_service.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/providers/merge_request_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/merge_request_card.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockService extends Mock implements MergeRequestLinkService {}

const _url = 'https://xddlabs.com/root/tbchat/-/merge_requests/3458';

const _mr = Ticket(
  id: 'gl:mr:99',
  accountId: 'gl',
  projectId: 'gl:root/tbchat',
  providerType: ProviderType.gitlab,
  externalKey: '3458',
  externalType: 'MergeRequest',
  title: 'Fix login token refresh',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.done,
  providerStatus: 'merged',
  sourceHash: '',
  url: _url,
  providerEntity: TicketProviderEntity.gitlabItem(
    author: 'kan',
    additions: 1867,
    deletions: 106,
    changedFiles: 12,
  ),
);

void main() {
  late _MockService service;

  setUpAll(() => registerFallbackValue(ProviderType.gitlab));

  setUp(() => service = _MockService());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<Ticket> tickets,
  }) async {
    final container = ProviderContainer(
      overrides: [
        mergeRequestLinkServiceProvider.overrideWithValue(service),
        ticketsProvider.overrideWith((ref) => Stream.value(tickets)),
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
          home: const Scaffold(body: MergeRequestCard(url: _url)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the fetched state and opens it beside the chat', (
    tester,
  ) async {
    when(
      () => service.fetchMergeRequest(
        provider: any(named: 'provider'),
        host: any(named: 'host'),
        project: any(named: 'project'),
        number: any(named: 'number'),
      ),
    ).thenAnswer((_) async => const Ok('gl:mr:99'));

    final container = await pump(tester, tickets: [_mr]);

    verify(
      () => service.fetchMergeRequest(
        provider: ProviderType.gitlab,
        host: 'xddlabs.com',
        project: 'root/tbchat',
        number: '3458',
      ),
    ).called(1);
    expect(find.text('Fix login token refresh'), findsOneWidget);
    expect(find.textContaining('Merged', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('root/tbchat !3458', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('kan', findRichText: true), findsOneWidget);
    expect(find.textContaining('12 files', findRichText: true), findsOneWidget);
    expect(find.textContaining('+1,867', findRichText: true), findsOneWidget);

    await tester.tap(find.byType(MergeRequestCard));
    expect(container.read(openTicketIdProvider), 'gl:mr:99');
    // Ends the fetched state's freshness timer with the providers.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('without an account for the host it says so', (tester) async {
    when(
      () => service.fetchMergeRequest(
        provider: any(named: 'provider'),
        host: any(named: 'host'),
        project: any(named: 'project'),
        number: any(named: 'number'),
      ),
    ).thenAnswer((_) async => const Err(NotFoundFailure('none')));

    final container = await pump(tester, tickets: const []);

    expect(
      find.textContaining(
        'Connect an account for xddlabs.com to see its status',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('root/tbchat !3458', findRichText: true),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
