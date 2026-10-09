import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/debug/debug_celebrate_button.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/util/fireworks.dart';
import 'package:work_nexus/core/widgets/celebration_overlay.dart';

void main() {
  Future<WidgetRef> pump(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: CelebrationOverlay(child: child!),
          ),
          home: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return ref;
  }

  final fireworks = find.descendant(
    of: find.byType(CelebrationOverlay),
    matching: find.byType(CustomPaint),
  );

  testWidgets('a celebration plays a show, then clears', (tester) async {
    final ref = await pump(tester);
    expect(fireworks, findsNothing);

    ref.read(celebrationProvider.notifier).celebrate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fireworks, findsOneWidget);
    // Paint every stage of the show: bursts, tails, glows, fading.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.pump(fireworksDuration);
    expect(fireworks, findsNothing);
  });

  testWidgets('no show when the system asks for reduced motion', (
    tester,
  ) async {
    final ref = await pump(tester, reduceMotion: true);
    ref.read(celebrationProvider.notifier).celebrate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fireworks, findsNothing);
  });

  testWidgets('the debug button sets off a show', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, r, _) {
                ref = r;
                return const Center(child: DebugCelebrateButton());
              },
            ),
          ),
        ),
      ),
    );
    expect(ref.read(celebrationProvider), 0);
    await tester.tap(find.byType(DebugCelebrateButton));
    expect(ref.read(celebrationProvider), 1);
  });
}
