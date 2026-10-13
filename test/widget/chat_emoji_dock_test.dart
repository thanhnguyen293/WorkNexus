import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/data/repositories/local_sticker_repository.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_controller.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_emoji_picker.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_emoji_side_panel.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

const _thread = (accountId: 'acc', chatGid: 'g1');

void main() {
  late Directory mine;
  late ChatComposerController text;
  late FocusNode focus;

  setUp(() {
    mine = Directory.systemTemp.createTempSync('stickers');
    text = ChatComposerController();
    focus = FocusNode();
  });

  tearDown(() {
    mine.deleteSync(recursive: true);
    text.dispose();
    focus.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(_MockChatRepository()),
          stickerRepositoryProvider.overrideWithValue(
            LocalStickerRepository(
              bundle: rootBundle,
              directory: () async => mine,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          // The composer's button, and the panel beside the chat as the
          // thread pane shows it.
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ChatEmojiButton(
                        thread: _thread,
                        text: text,
                        focus: focus,
                        dockable: true,
                      ),
                    ),
                  ),
                  if (ref.watch(chatSidePanelProvider(_thread)) ==
                      ChatSidePanel.emoji)
                    const ChatEmojiSidePanel(thread: _thread),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  // A desktop app: on mobile, the closing popup's and the panel's loading
  // views would both claim the page's primary scroll controller.
  testWidgets(
    'the popup expands beside the chat, inserts emoji there, and '
    'collapses back',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Emoji'));
      await settle(tester);
      await tester.tap(find.byTooltip('Expand'));
      await settle(tester);

      expect(find.byType(ChatEmojiSidePanel), findsOneWidget);
      expect(find.byTooltip('Expand'), findsNothing);

      await tester.tap(find.text('Emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😀'));
      await tester.tap(find.text('😀'));
      await tester.pumpAndSettle();
      expect(text.plainText, '😀😀');
      expect(find.byType(ChatEmojiSidePanel), findsOneWidget);

      // Expanded, the button shows and hides the panel.
      await tester.tap(find.byTooltip('Emoji'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatEmojiSidePanel), findsNothing);
      await tester.tap(find.byTooltip('Emoji'));
      await settle(tester);
      expect(find.byType(ChatEmojiSidePanel), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatEmojiSidePanel), findsNothing);

      // Collapsed: the button opens the popup again.
      await tester.tap(find.byTooltip('Emoji'));
      await settle(tester);
      expect(find.byTooltip('Expand'), findsOneWidget);
    },
  );
}
