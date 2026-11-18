import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_sticker.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_suggestion_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_controller.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_sticker_suggestions_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockStickers extends Mock implements StickerController {}

const _thread = (accountId: 'a', chatGid: 'c');
const _key = (chat: _thread, inThread: false);

const _laugh = ChatSticker(
  id: 'laugh',
  pack: 'Pepe',
  name: '033.webp',
  location: 'assets/stickers/Pepe/033.webp',
  emoji: '😂🤣',
);
const _smile = ChatSticker(
  id: 'smile',
  pack: 'Pepe',
  name: '042.webp',
  location: 'assets/stickers/Pepe/042.webp',
  emoji: '😊',
);

void main() {
  late _MockStickers stickers;
  late ChatComposerController text;

  setUpAll(() {
    registerFallbackValue(_laugh);
    registerFallbackValue(_thread);
  });

  setUp(() {
    stickers = _MockStickers();
    when(
      () => stickers.send(any(), any(), replyToId: any(named: 'replyToId')),
    ).thenAnswer((_) async => const Ok(null));
    text = ChatComposerController();
  });

  Future<void> pump(
    WidgetTester tester, {
    ChatMessage? latest,
    bool suggestions = true,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          AppSettings(chatStickerSuggestions: suggestions),
        ),
        chatStickersProvider.overrideWith(
          (ref) async => const Ok([_laugh, _smile]),
        ),
        chatLatestMessageProvider.overrideWith(
          (ref, key) => Stream.value(latest),
        ),
        stickerControllerProvider.overrideWithValue(stickers),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: ChatStickerSuggestionsBar(
            draftKey: _key,
            text: text,
            focus: FocusNode(),
          ),
        ),
      ),
    ),
  );

  testWidgets('answers a thanks with a smile while nothing is typed', (
    tester,
  ) async {
    await pump(
      tester,
      latest: ChatMessage(
        accountId: 'a',
        gid: 'm1',
        chatGid: 'c',
        senderId: 2,
        sentAt: DateTime.now(),
        content: const TextContent('Cảm ơn em nhé'),
        isMine: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reply with a sticker'), findsOneWidget);
    expect(find.byTooltip('😊'), findsOneWidget);
    expect(find.byTooltip('😂🤣'), findsNothing);

    // Closed, it stays closed for that message.
    await tester.tap(find.byTooltip('Hide sticker suggestions'));
    await tester.pump();
    expect(find.text('Reply with a sticker'), findsNothing);
  });

  testWidgets('offers stickers for what is typed; one replaces the draft', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNothing);

    text.insertText('haha');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Send as a sticker'), findsOneWidget);

    await tester.tap(find.byTooltip('😂🤣'));
    await tester.pump();
    verify(() => stickers.send(_thread, _laugh)).called(1);
    // The sticker said all of it.
    expect(text.isBlank, isTrue);
  });

  testWidgets('suggests nothing while sticker suggestions are off', (
    tester,
  ) async {
    await pump(
      tester,
      suggestions: false,
      latest: ChatMessage(
        accountId: 'a',
        gid: 'm1',
        chatGid: 'c',
        senderId: 2,
        sentAt: DateTime.now(),
        content: const TextContent('Cảm ơn em nhé'),
        isMine: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reply with a sticker'), findsNothing);

    text.insertText('haha');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Send as a sticker'), findsNothing);
  });
}
