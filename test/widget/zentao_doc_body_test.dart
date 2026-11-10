import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_body.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_code_block.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_reader_controller.dart';

const _html =
    '<div><p><strong>Endpoint</strong></p></div>'
    '<pre class="shiki" style="background-color:#FFFFFF;color:#000000;">'
    '<code>GET /v1/hub/{id}\n</code></pre>'
    '<div><p></p></div>'
    '<table><thead><tr><th>Name</th><th>Type</th></tr></thead>'
    '<tbody><tr><td>user_id</td><td>string</td></tr></tbody></table>'
    '<p>Errors: <code>not_found</code></p>';

void main() {
  testWidgets('code blocks are numbered and unwrapped; inline code is a chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.dark,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ZenTaoDocBody(
                _html,
                reader: ZenTaoDocReader(),
                imageLoader: (_) async => null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final code = tester.widget<ZenTaoDocCodeBlock>(
      find.byType(ZenTaoDocCodeBlock),
    );
    expect(code.code, 'GET /v1/hub/{id}', reason: 'trailing newline dropped');
    expect(find.text('1'), findsOneWidget, reason: 'line numbers');
    expect(find.text('not_found'), findsOneWidget, reason: 'inline chip');
    expect(find.text('Endpoint', findRichText: true), findsOneWidget);
    expect(find.text('user_id', findRichText: true), findsOneWidget);
    expect(find.text('Type', findRichText: true), findsOneWidget);

    // Built whole in one box: the page's length is exact, the scrollbar
    // steady (no lazy sliver guessing it).
    expect(find.byType(SliverToBoxAdapter), findsOneWidget);
    expect(find.byType(SliverList), findsNothing);
  });

  testWidgets('a long page (built asynchronously) still sits in a sliver', (
    tester,
  ) async {
    // Past a few KB the library builds the page asynchronously, through a
    // placeholder that must be a sliver too — the case that once threw on
    // every frame.
    final long = List.filled(
      400,
      '<p>A long paragraph of the page.</p>',
    ).join();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: ZenTaoDocBody(
                  long,
                  reader: ZenTaoDocReader(),
                  imageLoader: (_) async => null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The placeholder frame: it must lay out inside the sliver padding.
    await tester.pump();
    expect(tester.takeException(), isNull);

    // The asynchronous build runs on the real clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('A long paragraph', findRichText: true),
      findsWidgets,
    );
  });
}
