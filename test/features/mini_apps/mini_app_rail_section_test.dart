import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/move_mini_app.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_providers.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/mini_app_rail_section.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _apps = [
  MiniApp(id: 'a', name: 'CI/CD', url: 'https://ci.example', position: 0),
  MiniApp(id: 'b', name: 'Zentao', url: 'https://zt.example', position: 1),
  MiniApp(id: 'c', name: 'Trello', url: 'https://trello.com', position: 2),
];

/// Records the moves asked for and sends the new order back, as the database
/// would.
class _FakeMove implements MoveMiniApp {
  _FakeMove(this.saved);

  final StreamController<List<MiniApp>> saved;
  final moves = <(int, int)>[];

  @override
  Future<Result<List<MiniApp>>> call(
    List<MiniApp> apps, {
    required int from,
    required int to,
  }) async {
    moves.add((from, to));
    final next = MoveMiniApp.reorder(apps, from: from, to: to);
    saved.add(next);
    return Ok(next);
  }
}

void main() {
  late StreamController<List<MiniApp>> saved;
  late _FakeMove move;
  late ProviderContainer container;

  Future<void> pumpRail(WidgetTester tester) async {
    saved = StreamController<List<MiniApp>>.broadcast();
    move = _FakeMove(saved);
    container = ProviderContainer(
      overrides: [
        miniAppsProvider.overrideWith((ref) async* {
          yield _apps;
          yield* saved.stream;
        }),
        moveMiniAppProvider.overrideWithValue(move),
      ],
    );
    addTearDown(container.dispose);
    // Not awaited: the done event never arrives outside the test's fake time.
    addTearDown(() => unawaited(saved.close()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.flat,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 76,
                height: 400,
                child: Column(children: [MiniAppRailSection()]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a click that wobbles a pixel opens the app, not a drag', (
    tester,
  ) async {
    await pumpRail(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Zentao')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 3));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(openMiniAppIdProvider), 'b');
    expect(move.moves, isEmpty);
  });

  testWidgets('holding an app, then dragging it, moves it', (tester) async {
    await pumpRail(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('CI/CD')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(move.moves, isNotEmpty);
    expect(move.moves.single.$1, 0);
  });
}
