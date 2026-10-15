import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app_permission.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/mini_app_permission_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/resolve_mini_app_permission.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_providers.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/ask_mini_app_permission.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_notifications.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockRepo extends Mock implements MiniAppPermissionRepository {}

class _Shown extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
}

final _shownProvider = NotifierProvider<_Shown, bool>(_Shown.new);

const _app = MiniApp(id: 'a', name: 'A', url: 'https://a.io/', position: 0);
const _kinds = [MiniAppPermissionKind.notifications];
final _onSite = Uri.parse('https://a.io/inbox');

void main() {
  late _MockRepo repo;
  late BuildContext context;
  late WidgetRef ref;

  setUpAll(() {
    registerFallbackValue(MiniAppPermissionKind.other);
    registerFallbackValue(
      const MiniAppPermissionGrant(
        miniAppId: 'a',
        kind: MiniAppPermissionKind.other,
        decision: MiniAppPermissionDecision.block,
      ),
    );
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.save(any())).thenAnswer((_) async => const Ok(null));
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        miniAppPermissionRepositoryProvider.overrideWithValue(repo),
        resolveMiniAppPermissionProvider.overrideWithValue(
          ResolveMiniAppPermission(repo),
        ),
        miniAppShownProvider.overrideWith(
          (ref, id) => ref.watch(_shownProvider),
        ),
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
          body: Consumer(
            builder: (c, r, _) {
              context = c;
              ref = r;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );

  void remembered(MiniAppPermissionDecision? decision) => when(
    () => repo.decisionFor('a', MiniAppPermissionKind.notifications),
  ).thenAnswer((_) async => Ok(decision));

  testWidgets('a page on another site is blocked without asking', (
    tester,
  ) async {
    await pump(tester);
    remembered(MiniAppPermissionDecision.allow);
    final answer = await askMiniAppPermission(
      context,
      ref,
      _app,
      _kinds,
      origin: Uri.parse('https://evil.example/'),
    );
    expect(answer, MiniAppPermissionDecision.block);
    verifyNever(() => repo.decisionFor(any(), any()));
  });

  testWidgets('a remembered answer comes back even while hidden', (
    tester,
  ) async {
    await pump(tester);
    remembered(MiniAppPermissionDecision.allow);
    final answer = await askMiniAppPermission(
      context,
      ref,
      _app,
      _kinds,
      origin: _onSite,
    );
    expect(answer, MiniAppPermissionDecision.allow);
    verifyNever(() => repo.save(any()));
  });

  testWidgets('a hidden app asks once it is opened, and remembers', (
    tester,
  ) async {
    await pump(tester);
    remembered(null);
    MiniAppPermissionDecision? answer;
    unawaited(
      askMiniAppPermission(
        context,
        ref,
        _app,
        _kinds,
        origin: _onSite,
      ).then((a) => answer = a),
    );
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsNothing);

    ref.read(_shownProvider.notifier).show();
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    // Resolves at all: the in-flight entry must not wait on itself.
    expect(answer, MiniAppPermissionDecision.allow);
    verify(() => repo.save(any())).called(1);
  });

  testWidgets('two requests at once share one dialog', (tester) async {
    await pump(tester);
    remembered(null);
    ref.read(_shownProvider.notifier).show();
    final answers = <MiniAppPermissionDecision>[];
    for (var i = 0; i < 2; i++) {
      unawaited(
        askMiniAppPermission(
          context,
          ref,
          _app,
          _kinds,
          origin: _onSite,
        ).then(answers.add),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('Block'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(answers, [
      MiniAppPermissionDecision.block,
      MiniAppPermissionDecision.block,
    ]);
  });

  group('notification bridge token', () {
    test('only calls carrying the token are its own', () {
      final capability = MiniAppNotificationCapability(token: 'secret');
      expect(capability.isOwnCall(['secret', 'title']), isTrue);
      expect(capability.isOwnCall(['title']), isFalse);
      expect(capability.isOwnCall(const []), isFalse);
      expect(capability.userScript.source, contains("'secret'"));
    });

    test('each web view gets its own token', () {
      expect(
        MiniAppNotificationCapability().token,
        isNot(MiniAppNotificationCapability().token),
      );
    });
  });
}
