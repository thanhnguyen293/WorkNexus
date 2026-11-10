import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_body.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_code_block.dart';

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
            slivers: [ZenTaoDocBody(_html, imageLoader: (_) async => null)],
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
  });
}
