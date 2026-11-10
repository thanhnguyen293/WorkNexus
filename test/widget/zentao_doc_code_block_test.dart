import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_code_block.dart';

void main() {
  Future<double> heightOf(WidgetTester tester, String code) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: ZenTaoDocCodeBlock(code, fontSize: 13),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(ZenTaoDocCodeBlock)).height;
  }

  testWidgets('a line wider than the block adds no empty space below it', (
    tester,
  ) async {
    final short = await heightOf(tester, 'a\nb');
    final long = await heightOf(tester, '${'x' * 400}\nb');
    expect(long, short);
  });
}
