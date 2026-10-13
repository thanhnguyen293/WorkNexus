import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_controller.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_field.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_markdown_toolbar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  late ChatComposerController text;
  late FocusNode focus;

  setUp(() {
    text = ChatComposerController();
    focus = FocusNode();
  });

  tearDown(() {
    text.dispose();
    focus.dispose();
  });

  Future<void> pump(WidgetTester tester, {required bool markdown}) {
    text.markdown = markdown;
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: const [
          ...AppL10n.localizationsDelegates,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: ChatComposerField(
            controller: text,
            focus: focus,
            autofocus: false,
            markdown: markdown,
            onSend: () {},
            onLike: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('plain mode has no formatting toolbar', (tester) async {
    await pump(tester, markdown: false);
    expect(find.byType(ChatMarkdownToolbar), findsNothing);
  });

  testWidgets('markdown mode formats the selection from the toolbar', (
    tester,
  ) async {
    await pump(tester, markdown: true);
    expect(find.byType(ChatMarkdownToolbar), findsOneWidget);

    text.insertText('say hi');
    text.quill.updateSelection(
      const TextSelection(baseOffset: 4, extentOffset: 6),
      ChangeSource.local,
    );
    await tester.tap(find.byIcon(LucideIcons.bold300));
    await tester.pump();
    expect(text.messageText, 'say **hi**');

    await tester.tap(find.byIcon(LucideIcons.list300));
    await tester.pump();
    expect(text.messageText, '- say **hi**');
  });

  testWidgets('expanding toggles the button', (tester) async {
    await pump(tester, markdown: true);
    await tester.tap(find.byIcon(LucideIcons.maximize2300));
    await tester.pump();
    expect(find.byIcon(LucideIcons.minimize2300), findsOneWidget);
  });

  testWidgets('a mention shows as @Name in the accent', (tester) async {
    await pump(tester, markdown: false);
    text.insertText('@d');
    text.insertMention(0, 2, id: 41, name: 'Dyno');
    await tester.pump();
    final mention = tester.widget<Text>(find.text('@Dyno'));
    final context = tester.element(find.text('@Dyno'));
    expect(mention.style?.color, context.colors.accent);
  });
}
