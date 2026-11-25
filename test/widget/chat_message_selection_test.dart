import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_hover_actions.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_text_selection.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// The message list's selection: one `SelectionArea` around a reversed list
/// whose rows have a sender, a time and (selectable) message text.
void main() {
  late String? selected;
  late List<String> ran;
  late TapGestureRecognizer link;

  setUp(() {
    selected = null;
    ran = [];
    link = TapGestureRecognizer()..onTap = () => ran.add('link');
  });
  tearDown(() => link.dispose());

  Widget row(String text, String time, {InlineSpan? extra}) => Padding(
    padding: const EdgeInsets.all(8),
    child: MessageHoverActions(
      alignEnd: false,
      actions: [
        (
          icon: Icons.reply,
          tooltip: 'Reply',
          onTap: () => ran.add('Reply'),
          destructive: false,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Dyno'),
          MessageTextSelection(
            child: Text.rich(TextSpan(text: text, children: [?extra])),
          ),
          Text(time),
        ],
      ),
    ),
  );

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
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
          body: SelectionArea(
            contextMenuBuilder: null,
            onSelectionChanged: (content) => selected = content?.plainText,
            child: CustomScrollView(
              reverse: true,
              slivers: [
                MessageSelectionScope(
                  child: SliverList.list(
                    children: [
                      // Newest first: shown at the bottom.
                      row(
                        'newer message ',
                        '10:02',
                        extra: TextSpan(text: 'a link', recognizer: link),
                      ),
                      row('older message', '10:01'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('part of one message selects on its own', (tester) async {
    await pumpList(tester);
    final older = tester.getRect(find.text('older message'));

    await drag(
      tester,
      older.centerLeft,
      older.centerRight + const Offset(20, 0),
    );

    expect(selected, 'older message');
  });

  testWidgets('a drag down across messages takes only their text, a line '
      'apiece', (tester) async {
    await pumpList(tester);
    final older = tester.getRect(find.text('older message'));
    final newer = tester.getRect(
      find.text('newer message a link', findRichText: true),
    );

    await drag(tester, older.centerLeft, newer.centerRight);

    expect(selected, 'older message\nnewer message a link');
  });

  testWidgets('a drag up across messages reads the same', (tester) async {
    await pumpList(tester);
    final older = tester.getRect(find.text('older message'));
    final newer = tester.getRect(
      find.text('newer message a link', findRichText: true),
    );

    await drag(tester, newer.centerRight, older.centerLeft);

    expect(selected, 'older message\nnewer message a link');
  });

  testWidgets('a link in selectable message text still opens', (tester) async {
    await pumpList(tester);

    await tester.tapOnText(find.textRange.ofSubstring('a link'));
    await tester.pump();

    expect(ran, ['link']);
  });

  testWidgets('a right-click on message text opens the message menu', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(
      find.text('older message'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();

    expect(ran, ['Reply']);
  });
}
