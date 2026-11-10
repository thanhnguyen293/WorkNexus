import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_find_bar.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_reader_controller.dart';

void main() {
  testWidgets('a floating card: Enter steps, Escape closes', (tester) async {
    final reader = ZenTaoDocReader();
    addTearDown(reader.dispose);
    final queries = <String>[];
    var closed = false;
    await tester.pumpWidget(
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
          body: Align(
            alignment: Alignment.topRight,
            child: ZenTaoDocFindBar(
              reader: reader,
              query: '',
              onQuery: queries.add,
              onClose: () => closed = true,
            ),
          ),
        ),
      ),
    );

    // Its own width, not a band across the page.
    expect(tester.getSize(find.byType(ZenTaoDocFindBar)).width, 400);

    await tester.enterText(find.byType(TextField), 'token');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(queries, ['token'], reason: 'Enter marks a pending query at once');

    reader.resetMatches(3);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(reader.current.value, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
