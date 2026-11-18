import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/privacy_mask.dart';

/// Whether the [PrivacyFade] over the widget holding [text] fades it (or is
/// fading it: the opacity it eases to).
bool _fadedOver(WidgetTester tester, String text) =>
    tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity <
    1;

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
  return mouse;
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

const _name = PrivacyMask(
  masked: true,
  mask: Text(kPrivacyMaskText),
  child: Text('Alice'),
);

void main() {
  testWidgets('a mask shows dots in place of the text only while masked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            _name,
            PrivacyMask(
              masked: false,
              mask: Text('hidden'),
              child: Text('Bob'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Alice'), findsNothing);
    expect(find.text(kPrivacyMaskText), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('a centered title stays centered inside a mask', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            // A list stretches its rows, as the chat info panel's does.
            child: ListView(
              children: const [
                PrivacyMask(
                  masked: false,
                  mask: Text(kPrivacyMaskText, textAlign: TextAlign.center),
                  child: Text('Team', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // As wide as the list, so its own centering puts the words mid-way.
    expect(tester.getSize(find.text('Team')).width, 400);
  });

  testWidgets('pointing at a mask shows the text until the pointer leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_name));
    final mouse = await _hover(tester, find.text(kPrivacyMaskText));
    expect(find.text('Alice'), findsOneWidget);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('a fade dims the message without changing it', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            PrivacyFade(faded: true, child: Text('secret')),
            PrivacyFade(faded: false, child: Text('plain')),
          ],
        ),
      ),
    );
    expect(_fadedOver(tester, 'secret'), isTrue);
    expect(_fadedOver(tester, 'plain'), isFalse);
  });

  testWidgets('keyboard focus inside a fade shows it', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        PrivacyFade(
          faded: true,
          child: Focus(focusNode: focus, child: const Text('secret')),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(_fadedOver(tester, 'secret'), isFalse);

    focus.unfocus();
    await tester.pump();
    // The focus change lands as that frame builds; its rebuild is next.
    await tester.pump();
    expect(_fadedOver(tester, 'secret'), isTrue);
  });

  testWidgets('pointing anywhere on a region shows all of it', (tester) async {
    await tester.pumpWidget(
      _app(
        const PrivacyRevealRegion(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrivacyMask(
                masked: true,
                mask: SizedBox(width: 40, height: 20),
                child: Text('avatar'),
              ),
              _name,
            ],
          ),
        ),
      ),
    );
    await _hover(tester, find.text(kPrivacyMaskText));
    expect(find.text('avatar'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('fading in and out keeps the message state', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget field(bool faded) => _app(
      PrivacyFade(
        faded: faded,
        child: SizedBox(width: 200, child: TextField(controller: controller)),
      ),
    );
    await tester.pumpWidget(field(false));
    final state = tester.state(find.byType(TextField));

    await tester.pumpWidget(field(true));
    expect(tester.state(find.byType(TextField)), same(state));
  });

  testWidgets('a region around a text field ignores focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        PrivacyRevealRegion(
          revealOnFocus: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PrivacyFade(faded: true, child: Text('secret')),
              Focus(focusNode: focus, child: const Text('input')),
            ],
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(_fadedOver(tester, 'secret'), isTrue);

    await _hover(tester, find.text('secret'));
    expect(_fadedOver(tester, 'secret'), isFalse);
  });

  testWidgets('a cover hides a picture under a solid box, kept built', (
    tester,
  ) async {
    Widget picture(bool covered) => _app(
      PrivacyCover(
        covered: covered,
        color: const Color(0xFF808080),
        child: const SizedBox(width: 80, height: 60, child: Text('photo')),
      ),
    );
    final box = find.descendant(
      of: find.byType(PrivacyCover),
      matching: find.byType(DecoratedBox),
    );
    // The box eases in and out; this is the opacity it eases to.
    bool covered() =>
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(of: box, matching: find.byType(AnimatedOpacity)),
            )
            .opacity ==
        1;
    await tester.pumpWidget(picture(false));
    expect(covered(), isFalse);
    final state = tester.element(find.text('photo'));

    await tester.pumpWidget(picture(true));
    expect(covered(), isTrue);
    expect(tester.getSize(box), const Size(80, 60));
    expect(tester.element(find.text('photo')), same(state));

    await _hover(tester, find.byType(PrivacyCover));
    expect(covered(), isFalse);
  });
}
