import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_fit_cards.dart';

/// A box that can be laid out but not measured, like the list items
/// gpt_markdown draws: asking its dry layout is an assertion in debug.
class _LayoutOnly extends LeafRenderObjectWidget {
  const _LayoutOnly(this.width);

  final double width;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutOnly(width);
}

class _RenderLayoutOnly extends RenderBox {
  _RenderLayoutOnly(this.width);

  final double width;

  @override
  void performLayout() => size = constraints.constrain(Size(width, 20));
}

const _cardKey = ValueKey('card');
const _contentKey = ValueKey('content');

Future<void> _pump(WidgetTester tester, Widget content, {double card = 80}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: MessageFitCards(
              content: KeyedSubtree(key: _contentKey, child: content),
              cards: ColoredBox(
                key: _cardKey,
                color: Colors.blue,
                child: SizedBox(width: card, height: 30),
              ),
              footer: const Text('09:41'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('content that can only be laid out does not break the bubble', (
    tester,
  ) async {
    await _pump(
      tester,
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Deadline: '),
            WidgetSpan(child: _LayoutOnly(150)),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // The cards take the content's width, which is wider than theirs.
    expect(
      tester.getSize(find.byKey(_cardKey)).width,
      tester.getSize(find.byKey(_contentKey)).width,
    );
  });

  testWidgets('a Markdown list with a link card lays out', (tester) async {
    await _pump(
      tester,
      const GptMarkdown('Deadline:\n\n1. Edit posts\n2. Comments'),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(_cardKey), findsOneWidget);
  });

  testWidgets('wider cards size the bubble, up to its maximum', (tester) async {
    await _pump(tester, const Text('ok'), card: 260);
    expect(tester.getSize(find.byKey(_cardKey)).width, 260);

    await _pump(tester, const Text('ok'), card: 900);
    expect(tester.getSize(find.byKey(_cardKey)).width, 400);
    expect(tester.takeException(), isNull);
  });
}
