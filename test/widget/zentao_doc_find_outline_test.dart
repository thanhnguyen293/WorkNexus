import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/util/zentao_doc_prepare.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_body.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_inline.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_outline.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_reader_controller.dart';

Widget _app(Widget body) => MaterialApp(
  theme: buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  ),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(body: body),
);

/// A page of [sections] headings, each followed by a tall run of text.
String _sections(int sections) => [
  for (var i = 0; i < sections; i++)
    '<h2>Section $i</h2>${List.filled(12, '<p>Body of section $i.</p>').join()}',
].join();

void main() {
  late ZenTaoDocReader reader;
  setUp(() => reader = ZenTaoDocReader());
  tearDown(() => reader.dispose());

  testWidgets('matches are marked in text and code; next steps through', (
    tester,
  ) async {
    final p = prepareZenTaoDocHtml(
      '<p>Token and <b>token</b></p><pre><code>TOKEN=1</code></pre>',
      query: 'token',
    );
    await tester.pumpWidget(
      _app(
        CustomScrollView(
          slivers: [
            ZenTaoDocBody(
              p.html,
              reader: reader,
              imageLoader: (_) async => null,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    reader.resetMatches(p.matchCount);

    expect(p.matchCount, 3);
    // The prose matches are marks; the code one is highlighted in its block.
    expect(find.byType(ZenTaoDocFindMark), findsNWidgets(2));
    expect(reader.current.value, 0);

    reader.next();
    reader.next();
    expect(reader.current.value, 2);
    reader.next();
    expect(reader.current.value, 0, reason: 'wraps around');
    reader.previous();
    expect(reader.current.value, 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the outline scrolls to a heading and lights it', (tester) async {
    final p = prepareZenTaoDocHtml(_sections(6));
    final scroll = ScrollController();
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: scroll,
                slivers: [
                  ZenTaoDocBody(
                    p.html,
                    reader: reader,
                    imageLoader: (_) async => null,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 240,
              child: ZenTaoDocOutline(headings: p.headings, reader: reader),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Section 4').last);
    await tester.pumpAndSettle();

    expect(reader.activeHeading.value, 4);
    expect(scroll.offset, greaterThan(0));
    // The heading's text sits just below the top edge, not cut off above it.
    final title = tester.getRect(
      find.textContaining('Section 4', findRichText: true).first,
    );
    final page = tester.getRect(find.byType(Scrollable).first);
    expect(title.top - page.top, inInclusiveRange(0, 60));
  });

  testWidgets('the heading being read is the last one scrolled past', (
    tester,
  ) async {
    final p = prepareZenTaoDocHtml(_sections(6));
    final scroll = ScrollController();
    await tester.pumpWidget(
      _app(
        CustomScrollView(
          controller: scroll,
          slivers: [
            ZenTaoDocBody(
              p.html,
              reader: reader,
              imageLoader: (_) async => null,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final viewport = tester.renderObject<RenderBox>(find.byType(Scrollable));

    reader.trackHeading(viewport, lead: 80, atEnd: false);
    expect(reader.activeHeading.value, 0);

    final third = reader.headingKey(3).currentContext!;
    scroll.jumpTo(
      scroll.offset +
          (third.findRenderObject()! as RenderBox)
              .localToGlobal(Offset.zero, ancestor: viewport)
              .dy -
          10,
    );
    await tester.pump();
    reader.trackHeading(viewport, lead: 80, atEnd: false);
    expect(reader.activeHeading.value, 3);
  });
}
