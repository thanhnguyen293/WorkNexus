import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_sticker.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_repository.dart';
import 'package:work_nexus/features/chat/presentation/providers/sticker_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_sticker_pack_bar.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_sticker_panel.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _Stickers extends Mock implements StickerRepository {}

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
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
          body: Center(child: SizedBox(width: 340, height: 400, child: child)),
        ),
      ),
    );

ChatStickerPackCover _set(String id) =>
    (pack: id, title: id, cover: null, removable: false);

void main() {
  Widget bar(int sets, {String selected = ''}) => ChatStickerPackBar(
    packs: [for (var i = 0; i < sets; i++) _set(i == 0 ? '' : 'set$i')],
    selected: selected,
    onSelect: (_) {},
    onAdd: () {},
    onImport: () {},
    onRemove: (_) {},
  );

  double offset(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  testWidgets('a few sets need no arrows', (tester) async {
    await tester.pumpWidget(_app(bar(2)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Previous sets'), findsNothing);
    expect(find.byTooltip('Next sets'), findsNothing);
  });

  testWidgets('arrows scroll sets that do not fit, a page at a time', (
    tester,
  ) async {
    await tester.pumpWidget(_app(bar(12)));
    await tester.pumpAndSettle();
    final back = find.byTooltip('Previous sets');
    final next = find.byTooltip('Next sets');
    expect(back, findsOneWidget);
    expect(next, findsOneWidget);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(0));

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
  });

  testWidgets('the selected set is scrolled into view on opening', (
    tester,
  ) async {
    await tester.pumpWidget(_app(bar(12, selected: 'set11')));
    await tester.pumpAndSettle();

    expect(offset(tester), greaterThan(0));
  });

  testWidgets('the panel opens on the set last picked from, and remembers', (
    tester,
  ) async {
    final repo = _Stickers();
    when(repo.lastPack).thenAnswer((_) async => const Ok('B'));
    when(
      () => repo.rememberPack(any()),
    ).thenAnswer((_) async => const Ok(null));
    ChatSticker sticker(String pack, String name) =>
        ChatSticker(id: '$pack/$name', pack: pack, name: name, location: name);

    await tester.pumpWidget(
      _app(
        ChatStickerPanel(
          stickers: [sticker('A', 'a1.png'), sticker('B', 'b1.png')],
          onPick: (_) {},
        ),
        overrides: [stickerRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pump();

    final panelBar = tester.widget<ChatStickerPackBar>(
      find.byType(ChatStickerPackBar),
    );
    expect(panelBar.selected, 'B');

    await tester.tap(find.byTooltip('A'));
    await tester.pump();
    verify(() => repo.rememberPack('A')).called(1);
  });
}
