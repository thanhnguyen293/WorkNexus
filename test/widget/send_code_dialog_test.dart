import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/send_code_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  late ChatCodeDraft? result;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await SendCodeDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sends nothing until there is code', (tester) async {
    await open(tester);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.byType(SendCodeDialog), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('returns the name, language and code as typed', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).first, ' main.go ');
    await tester.enterText(find.byType(TextField).last, '  x := 1\n');
    await tester.tap(find.text('text'));
    await tester.pumpAndSettle();
    // The language list is searchable.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search languages…'),
      'script',
    );
    await tester.pumpAndSettle();
    expect(find.text('javascript'), findsOneWidget);
    expect(find.text('python'), findsNothing);
    await tester.tap(find.text('typescript'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.byType(SendCodeDialog), findsNothing);
    expect(result, (
      code: '  x := 1\n',
      language: 'typescript',
      name: 'main.go',
    ));
  });
}
