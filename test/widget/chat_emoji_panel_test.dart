import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/data/repositories/local_sticker_repository.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_emoji_panel.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository chats;
  late Directory mine;
  var sent = 0;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    chats = _MockChatRepository();
    mine = Directory.systemTemp.createTempSync('stickers');
    sent = 0;
    when(() => chats.sendEmoji(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));
    when(
      () => chats.sendFile(
        any(),
        any(),
        name: any(named: 'name'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(() => mine.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(chats),
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
          home: Scaffold(
            body: Center(
              child: ChatEmojiPanel(
                thread: (accountId: 'acc', chatGid: 'g1'),
                onInsert: (_) {},
                onSent: () => sent++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('a large emoji is sent in its wire form and closes the panel', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Stickers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😀').last);
    await tester.pumpAndSettle();

    verify(() => chats.sendEmoji('acc', 'g1', ':grinning:')).called(1);
    expect(sent, 1);
  });

  testWidgets('the bundled set has its own tab and sends as an image', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('My stickers'), findsOneWidget);
    await tester.ensureVisible(find.text('WorkNexus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WorkNexus'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byType(Image).first);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    verify(
      () => chats.sendFile(
        'acc',
        'g1',
        name: any(named: 'name', that: endsWith('.png')),
        bytes: any(named: 'bytes', that: isNotEmpty),
      ),
    ).called(1);
  });
}
