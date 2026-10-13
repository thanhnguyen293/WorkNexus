import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/code_block.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  final code = List.generate(25, (i) => 'line ${i + 1}').join('\n');

  Future<void> pump(WidgetTester tester, String code, {int? collapsed}) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlock(code, fontSize: 12, collapsedLines: collapsed),
            ),
          ),
        ),
      );

  String shown(WidgetTester tester) =>
      tester.widget<SelectableText>(find.byType(SelectableText)).data!;

  testWidgets('long code shows its first lines until expanded', (tester) async {
    await pump(tester, code, collapsed: 10);
    expect(shown(tester).split('\n'), hasLength(10));

    await tester.tap(find.text('Show all 25 lines'));
    await tester.pump();
    expect(shown(tester), code);

    await tester.tap(find.text('Collapse'));
    await tester.pump();
    expect(shown(tester).split('\n'), hasLength(10));
  });

  testWidgets('short code and uncapped blocks show in full, no toggle', (
    tester,
  ) async {
    await pump(tester, 'a\nb', collapsed: 10);
    expect(shown(tester), 'a\nb');
    expect(find.textContaining('Show all'), findsNothing);

    await pump(tester, code);
    expect(shown(tester), code);
  });

  testWidgets('copy puts the whole code on the clipboard, even collapsed', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, code, collapsed: 10);

    await tester.tap(find.byTooltip('Copy code'));
    await tester.pump();
    expect(copied, code);
    expect(find.byTooltip('Copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byTooltip('Copy code'), findsOneWidget);
  });
}
