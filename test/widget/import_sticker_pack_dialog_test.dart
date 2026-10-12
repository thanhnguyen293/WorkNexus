import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/remote_sticker_set.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_pack_source.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_repository.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/import_sticker_pack_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _Source extends Mock implements StickerPackSource {}

class _Converter extends Mock implements StickerConverter {}

class _Stickers extends Mock implements StickerRepository {}

class _Tokens implements TelegramTokenStore {
  _Tokens([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

void main() {
  late _Source source;
  late _Converter converter;
  late _Stickers stickers;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    source = _Source();
    converter = _Converter();
    stickers = _Stickers();
    when(
      () => source.file(any(), token: any(named: 'token')),
    ).thenAnswer((_) async => Ok(Uint8List.fromList([1])));
    when(() => converter.stillToWebp(any())).thenAnswer(
      (call) async => Ok(call.positionalArguments.single as Uint8List),
    );
    when(
      () => stickers.addPack(
        any(),
        title: any(named: 'title'),
        stickers: any(named: 'stickers'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  void serveSet({required String token}) =>
      when(() => source.stickerSet('Cats', token: token)).thenAnswer(
        (_) async => const Ok(
          RemoteStickerSet(
            name: 'Cats',
            title: 'Cats!',
            stickers: [
              RemoteSticker(fileId: 'a', kind: RemoteStickerKind.still),
            ],
          ),
        ),
      );

  /// Opens the dialog from a button; [result] gets what it resolves to.
  Future<List<String?>> pump(
    WidgetTester tester,
    _Tokens tokens,
  ) async {
    final results = <String?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stickerPackSourceProvider.overrideWithValue(source),
          stickerConverterProvider.overrideWithValue(converter),
          stickerRepositoryProvider.overrideWithValue(stickers),
          telegramTokenStoreProvider.overrideWithValue(tokens),
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
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    results.add(await ImportStickerPackDialog.show(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('the first import asks for the token, then goes on in the background', (
    tester,
  ) async {
    serveSet(token: 'T1');
    final tokens = _Tokens();
    final results = await pump(tester, tokens);

    expect(find.text('Telegram bot token'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'https://t.me/addstickers/Cats',
    );
    await tester.enterText(find.byType(TextField).last, 'T1');
    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();

    // The dialog closes once the set is listed; the rest runs on.
    expect(results.single, 'Cats!');
    expect(tokens.token, 'T1');
    verify(
      () => stickers.addPack(
        'tg:Cats',
        title: 'Cats!',
        stickers: any(named: 'stickers'),
      ),
    ).called(1);
  });

  testWidgets('a saved token is used without asking', (tester) async {
    serveSet(token: 'SAVED');
    final results = await pump(tester, _Tokens('SAVED'));

    expect(find.text('Using the saved bot token'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Cats');
    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();

    expect(results.single, 'Cats!');
  });

  testWidgets('a bad link is caught before Telegram is asked', (tester) async {
    await pump(tester, _Tokens('SAVED'));

    await tester.enterText(find.byType(TextField), 'not a link at all');
    await tester.tap(find.text('Add set'));
    await tester.pump();

    expect(
      find.text('Paste a link like https://t.me/addstickers/Name'),
      findsOneWidget,
    );
    verifyNever(() => source.stickerSet(any(), token: any(named: 'token')));
  });

  testWidgets('a refused token asks for another, keeping the dialog open', (
    tester,
  ) async {
    when(
      () => source.stickerSet('Cats', token: 'OLD'),
    ).thenAnswer((_) async => const Err(AuthFailure('refused')));
    final tokens = _Tokens('OLD');
    final results = await pump(tester, tokens);

    await tester.enterText(find.byType(TextField), 'Cats');
    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.text('Telegram refused this bot token.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tokens.token, 'OLD');
  });
}
