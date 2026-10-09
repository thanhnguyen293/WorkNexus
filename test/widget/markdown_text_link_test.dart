import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/markdown_text.dart';

void main() {
  Future<List<String>> pumpAndTap(
    WidgetTester tester,
    String markdown,
    String label, {
    bool Function(String url)? isPlainLink,
  }) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: MarkdownText(
            markdown,
            onLinkTap: tapped.add,
            isPlainLink: isPlainLink,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(label, findRichText: true));
    await tester.pump();
    return tapped;
  }

  testWidgets('a link renders its label and taps through to onLinkTap', (
    tester,
  ) async {
    final tapped = await pumpAndTap(
      tester,
      '[the docs](https://example.dev/a_b)',
      'the docs',
    );
    expect(tapped, ['https://example.dev/a_b']);
  });

  testWidgets('a plain link still taps through', (tester) async {
    final tapped = await pumpAndTap(
      tester,
      '[#42](https://z.example.com/bug-view-42.html)',
      '#42',
      isPlainLink: (_) => true,
    );
    expect(tapped, ['https://z.example.com/bug-view-42.html']);
  });
}
