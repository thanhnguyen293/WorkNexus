import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_field.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_markdown_toolbar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  late TextEditingController text;
  late FocusNode focus;
  late UndoHistoryController undo;

  setUp(() {
    text = TextEditingController();
    focus = FocusNode();
    undo = UndoHistoryController();
  });

  tearDown(() {
    text.dispose();
    focus.dispose();
    undo.dispose();
  });

  Future<void> pump(WidgetTester tester, {required bool markdown}) =>
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
            body: ChatComposerField(
              controller: text,
              focus: focus,
              undo: undo,
              autofocus: false,
              markdown: markdown,
              onSend: () {},
              onLike: () {},
            ),
          ),
        ),
      );

  testWidgets('plain mode has no formatting toolbar', (tester) async {
    await pump(tester, markdown: false);
    expect(find.byType(ChatMarkdownToolbar), findsNothing);
  });

  testWidgets('markdown mode formats the selection from the toolbar', (
    tester,
  ) async {
    await pump(tester, markdown: true);
    expect(find.byType(ChatMarkdownToolbar), findsOneWidget);

    text.value = const TextEditingValue(
      text: 'say hi',
      selection: TextSelection(baseOffset: 4, extentOffset: 6),
    );
    await tester.tap(find.byIcon(LucideIcons.bold300));
    await tester.pump();
    expect(text.text, 'say **hi**');
    expect(text.selection, const TextSelection(baseOffset: 6, extentOffset: 8));

    await tester.tap(find.byIcon(LucideIcons.list300));
    await tester.pump();
    expect(text.text, '- say **hi**');
  });

  testWidgets('expanding toggles the button', (tester) async {
    await pump(tester, markdown: true);
    await tester.tap(find.byIcon(LucideIcons.maximize2300));
    await tester.pump();
    expect(find.byIcon(LucideIcons.minimize2300), findsOneWidget);
  });
}
