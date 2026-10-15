import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/translation_state.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/translation/presentation/translation_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/widgets/ticket_card.dart';

const _sampleTicket = Ticket(
  id: 'zt:101',
  accountId: 'acc1',
  projectId: 'p1',
  providerType: ProviderType.zentao,
  externalKey: '101',
  externalType: 'Bug',
  title: 'Sample ticket title for UI testing',
  body: 'Body text',
  priority: Priority.high,
  status: UnifiedStatus.inprogress,
  providerStatus: 'active',
  sourceHash: 'hash',
  assignee: 'Alice',
  url: 'https://example.com/zt/101',
);

void main() {
  Widget buildHarness({Ticket ticket = _sampleTicket, String? selectedId}) {
    return ProviderScope(
      overrides: [
        lookupsProvider.overrideWithValue((
          accounts: const {},
          workspaces: const {},
          projects: const {},
        )),
        initialAppSettingsProvider.overrideWithValue(const AppSettings()),
        openTicketIdProvider.overrideWithValue(selectedId),
        translationStatusProvider(
          ticket.id,
        ).overrideWithValue((state: TranslationState.none, record: null)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: 256, child: TicketCard(ticket))),
        ),
      ),
    );
  }

  testWidgets('renders monospace ticket ref, title, and assignee chip', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Bug #101'), findsOneWidget);
    expect(find.text('Sample ticket title for UI testing'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('renders unassigned placeholder when assignee is null or empty', (
    tester,
  ) async {
    final unassigned = _sampleTicket.copyWith(assignee: null);
    await tester.pumpWidget(buildHarness(ticket: unassigned));
    await tester.pumpAndSettle();

    expect(find.text('Bug #101'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
  });

  testWidgets('clamps long title to max 3 lines with ellipsis', (tester) async {
    final longTicket = _sampleTicket.copyWith(
      title:
          'This is an exceptionally long ticket title that spans across multiple '
          'lines to thoroughly test that text wrapping and maxLines clamping '
          'behave properly without causing any layout overflows or unexpected clipping.',
    );
    await tester.pumpWidget(buildHarness(ticket: longTicket));
    await tester.pumpAndSettle();

    final titleWidget = tester.widget<Text>(find.text(longTicket.title));
    expect(titleWidget.maxLines, 3);
    expect(titleWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets('clicking ticket card navigates to openTicket', (tester) async {
    final container = ProviderContainer(
      overrides: [
        lookupsProvider.overrideWithValue((
          accounts: const {},
          workspaces: const {},
          projects: const {},
        )),
        initialAppSettingsProvider.overrideWithValue(const AppSettings()),
        translationStatusProvider(
          _sampleTicket.id,
        ).overrideWithValue((state: TranslationState.none, record: null)),
      ],
    );
    addTearDown(container.dispose);

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
          home: const Scaffold(
            body: Center(
              child: SizedBox(width: 256, child: TicketCard(_sampleTicket)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(openTicketIdProvider), isNull);

    await tester.tap(find.byType(TicketCard));
    await tester.pumpAndSettle();

    expect(container.read(openTicketIdProvider), _sampleTicket.id);
  });
}
