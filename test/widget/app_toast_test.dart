import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_snack.dart';
import 'package:work_nexus/core/widgets/app_toast_controller.dart';
import 'package:work_nexus/core/widgets/app_toast_host.dart';

void main() {
  group('AppToastController', () {
    test('newest first, a repeat moves up, at most three', () {
      final c = AppToastController();
      for (final m in ['a', 'b', 'c', 'd']) {
        c.show(m);
      }
      expect(c.toasts.map((t) => t.message), ['d', 'c', 'b']);

      c.show('c', kind: AppToastKind.error);
      expect(c.toasts.map((t) => t.message), ['c', 'd', 'b']);
      expect(c.toasts.first.kind, AppToastKind.error);

      c.dismiss(c.toasts.first.id);
      expect(c.toasts.map((t) => t.message), ['d', 'b']);
    });
  });

  Future<void> pump(WidgetTester tester, {required VoidCallback onTap}) =>
      tester.pumpWidget(
        AppToasts(
          child: MaterialApp(
            theme: buildAppTheme(
              variant: AppThemeVariant.light,
              surface: SurfaceStyle.outline,
              density: AppDensity.comfortable,
            ),
            builder: (context, child) =>
                AppToastLayer(child: child ?? const SizedBox.shrink()),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () => showAppSnack(context, 'Copied'),
                      child: const Text('copy'),
                    ),
                    TextButton(
                      onPressed: () =>
                          showAppSnack(context, 'Upload failed', isError: true),
                      child: const Text('fail'),
                    ),
                    TextButton(
                      onPressed: () => showAppSnack(
                        context,
                        'Link expired',
                        kind: AppToastKind.warning,
                      ),
                      child: const Text('warn'),
                    ),
                    TextButton(onPressed: onTap, child: const Text('bottom')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('shows at the top, leaves the bottom clickable, then goes', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);

    await tester.tap(find.text('copy'));
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final screen = tester.getSize(find.byType(Scaffold));
    expect(
      tester.getCenter(find.text('Copied')).dy,
      lessThan(screen.height / 3),
    );

    await tester.tap(find.text('bottom'));
    expect(taps, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copied'), findsNothing);
  });

  testWidgets('an error stays longer and a click dismisses it', (tester) async {
    await pump(tester, onTap: () {});

    await tester.tap(find.text('fail'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Upload failed'), findsOneWidget);

    await tester.tap(find.text('Upload failed'));
    await tester.pump();
    expect(find.text('Upload failed'), findsNothing);
  });

  testWidgets('a warning shows its glyph and outlasts a confirmation', (
    tester,
  ) async {
    await pump(tester, onTap: () {});

    await tester.tap(find.text('warn'));
    await tester.pump();
    expect(find.byIcon(LucideIcons.triangleAlert300), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Link expired'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Link expired'), findsNothing);
  });
}
