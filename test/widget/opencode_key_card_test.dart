import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/entities/opencode_credential.dart';
import 'package:work_nexus/core/domain/repositories/opencode_auth_repository.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/presentation/opencode_key_dialog.dart';
import 'package:work_nexus/features/connections/presentation/widgets/opencode_key_card.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockOpenCodeAuthRepository extends Mock
    implements OpenCodeAuthRepository {}

const _apiKeyCredential = OpenCodeCredential(
  providerId: 'opencode-go',
  type: OpenCodeAuthType.api,
  keyPreview: '••••••a1b2',
);

const _oauthCredential = OpenCodeCredential(
  providerId: 'anthropic',
  type: OpenCodeAuthType.oauth,
);

void main() {
  late _MockOpenCodeAuthRepository repository;

  setUp(() async {
    repository = _MockOpenCodeAuthRepository();
    await getIt.reset();
    getIt.registerSingleton<OpenCodeAuthRepository>(repository);
  });

  tearDown(getIt.reset);

  void stubCredentials(List<OpenCodeCredential> credentials) =>
      when(() => repository.listCredentials())
          .thenAnswer((_) async => Ok(credentials));

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: OpenCodeKeyCard()),
          ),
        ),
      ),
    );
    // Two frames: one to run the provider's future, one to render its data.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a stored key masked, never in full', (tester) async {
    stubCredentials(const [_apiKeyCredential]);

    await pumpCard(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('opencode-go'), findsOneWidget);
    expect(find.text('••••••a1b2'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Change key'), findsOneWidget);
  });

  testWidgets('offers to add a key when nothing is linked', (tester) async {
    stubCredentials(const []);

    await pumpCard(tester);

    expect(find.text('No provider is linked to OpenCode yet.'), findsOneWidget);
    expect(find.text('Change key'), findsNothing);
    expect(find.text('Add API key'), findsOneWidget);
  });

  testWidgets('an OAuth login is listed but not editable here', (tester) async {
    stubCredentials(const [_oauthCredential]);

    await pumpCard(tester);

    expect(find.text('anthropic'), findsOneWidget);
    expect(find.text('OAuth'), findsOneWidget);
    expect(find.text('Change key'), findsNothing);
    expect(find.text('Unlink'), findsOneWidget);
  });

  testWidgets('a read failure is reported instead of an empty list', (
    tester,
  ) async {
    when(() => repository.listCredentials()).thenAnswer(
      (_) async => const Err(ParseFailure('auth.json is not valid JSON')),
    );

    await pumpCard(tester);

    expect(find.text('auth.json is not valid JSON'), findsOneWidget);
  });

  testWidgets('Change key opens the dialog pinned to that provider', (
    tester,
  ) async {
    stubCredentials(const [_apiKeyCredential]);

    await pumpCard(tester);
    await tester.tap(find.text('Change key'));
    await tester.pumpAndSettle();

    expect(find.byType(OpenCodeKeyDialog), findsOneWidget);
    expect(find.text('Change the opencode-go key'), findsOneWidget);
    // The provider is fixed here, so only the key field is offered.
    final inDialog = find.descendant(
      of: find.byType(OpenCodeKeyDialog),
      matching: find.byType(TextField),
    );
    expect(inDialog, findsOneWidget);
    expect(find.text('Provider'), findsNothing);
  });

  testWidgets('saving writes the new key and refreshes the list', (
    tester,
  ) async {
    stubCredentials(const [_apiKeyCredential]);
    when(
      () =>
          repository.saveApiKey(providerId: 'opencode-go', key: 'new-key-9999'),
    ).thenAnswer((_) async {
      stubCredentials(const [
        OpenCodeCredential(
          providerId: 'opencode-go',
          type: OpenCodeAuthType.api,
          keyPreview: '••••••9999',
        ),
      ]);
      return const Ok(null);
    });

    await pumpCard(tester);
    await tester.tap(find.text('Change key'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new-key-9999');
    await tester.pump();
    await tester.tap(find.text('Save key'));
    await tester.pumpAndSettle();

    verify(
      () =>
          repository.saveApiKey(providerId: 'opencode-go', key: 'new-key-9999'),
    ).called(1);
    expect(find.byType(OpenCodeKeyDialog), findsNothing);
    expect(find.text('••••••9999'), findsOneWidget);
  });
}
