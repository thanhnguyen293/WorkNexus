import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_ai_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_ai_compose_button.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_controller.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _key = (chat: (accountId: 'a', chatGid: 'c'), inThread: false);

/// Counts the asks instead of calling the AI.
class _CountingSuggestions extends ChatReplySuggestionsController {
  _CountingSuggestions(super.composer);

  static var asked = 0;

  @override
  Future<void> suggest(ChatAiPeople people) async => asked++;
}

void main() {
  late ChatComposerController text;
  late ProviderContainer container;

  setUp(() {
    _CountingSuggestions.asked = 0;
    text = ChatComposerController();
  });

  Future<void> pump(WidgetTester tester) {
    container = ProviderContainer(
      overrides: [
        translatesWithApiKeyProvider.overrideWith((ref) async => true),
        chatAiPeopleProvider.overrideWith(
          (ref, accountId) => (selfName: 'An', nameOf: (id) => 'User $id'),
        ),
        chatReplySuggestionsProvider(
          _key,
        ).overrideWith(() => _CountingSuggestions(_key)),
      ],
    );
    addTearDown(container.dispose);
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: Center(
              child: ChatAiComposeButton(
                draftKey: _key,
                text: text,
                focus: FocusNode(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('AI tools'));
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing typed, the menu offers replies, the summary and '
      'the sticker switch, but no rewrites', (tester) async {
    await pump(tester);
    await openMenu(tester);

    expect(find.text('Suggest replies'), findsOneWidget);
    expect(find.text('Summarize with AI'), findsOneWidget);
    expect(find.text('Sticker suggestions'), findsOneWidget);
    expect(find.text('More formal'), findsNothing);

    await tester.tap(find.text('Suggest replies'));
    await tester.pumpAndSettle();
    expect(_CountingSuggestions.asked, 1);
  });

  testWidgets('the summary opens beside the chat', (tester) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Summarize with AI'));
    await tester.pumpAndSettle();

    expect(
      container.read(chatSidePanelProvider(_key.chat)),
      ChatSidePanel.assistant,
    );
  });

  testWidgets('the sticker switch turns suggestions off and back on', (
    tester,
  ) async {
    bool on() => container.read(appSettingsProvider).chatStickerSuggestions;
    await pump(tester);
    expect(on(), isTrue);

    await openMenu(tester);
    await tester.tap(find.text('Sticker suggestions'));
    await tester.pumpAndSettle();
    expect(on(), isFalse);

    await openMenu(tester);
    await tester.tap(find.text('Sticker suggestions'));
    await tester.pumpAndSettle();
    expect(on(), isTrue);
  });

  testWidgets('with a draft, the menu offers replies and rewrites', (
    tester,
  ) async {
    text.insertText('xong rồi nha');
    await pump(tester);
    await openMenu(tester);

    expect(find.text('Suggest replies'), findsOneWidget);
    expect(find.text('More formal'), findsOneWidget);
    expect(_CountingSuggestions.asked, 0);
  });
}
