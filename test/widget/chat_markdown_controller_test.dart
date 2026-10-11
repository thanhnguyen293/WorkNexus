import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_markdown_controller.dart';

void main() {
  late ChatMarkdownController controller;

  setUp(() => controller = ChatMarkdownController());
  tearDown(() => controller.dispose());

  Future<BuildContext> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );
    return tester.element(find.byType(TextField));
  }

  TextSpan? part(TextSpan span, String text) => span.children
      ?.whereType<TextSpan>()
      .where((s) => s.text == text)
      .firstOrNull;

  testWidgets('markdown on: content is styled, markers are faint', (
    tester,
  ) async {
    final context = await pump(tester);
    controller
      ..markdown = true
      ..text = 'say **hi**';
    final span = controller.buildTextSpan(
      context: context,
      withComposing: false,
    );

    expect(part(span, 'hi')?.style?.fontWeight, FontWeight.w700);
    expect(part(span, '**')?.style?.color, Colors.transparent);
    expect(part(span, 'say ')?.style, isNull);
  });

  testWidgets('a marker shows, faint, while the caret is inside it', (
    tester,
  ) async {
    final context = await pump(tester);
    controller
      ..markdown = true
      ..value = const TextEditingValue(
        text: 'a **b**',
        selection: TextSelection.collapsed(offset: 3),
      );
    final span = controller.buildTextSpan(
      context: context,
      withComposing: false,
    );
    final markers = span.children!
        .whereType<TextSpan>()
        .where((s) => s.text == '**')
        .map((s) => s.style?.color)
        .toList();

    expect(markers, hasLength(2));
    expect(markers.first, isNot(Colors.transparent));
    expect(markers.last, Colors.transparent);
  });

  testWidgets('markdown off: plain text', (tester) async {
    final context = await pump(tester);
    controller.text = 'say **hi**';
    final span = controller.buildTextSpan(
      context: context,
      withComposing: false,
    );

    expect(span.children, isNull);
    expect(span.text, 'say **hi**');
  });

  testWidgets('the word being composed keeps its underline', (tester) async {
    final context = await pump(tester);
    controller
      ..markdown = true
      ..value = const TextEditingValue(
        text: '**viet**',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 2, end: 6),
      );
    final span = controller.buildTextSpan(
      context: context,
      withComposing: true,
    );

    final word = part(span, 'viet')?.style;
    expect(word?.decoration, TextDecoration.underline);
    expect(word?.fontWeight, FontWeight.w700);
  });
}
