import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_header.dart';

void main() {
  testWidgets('copy link puts the document web address on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: ZenTaoDocToolbar(
              doc: const ZenTaoDoc(id: '50', title: 'Swap', libId: '89'),
              appBrightness: Brightness.light,
              syncing: false,
              onRefresh: () {},
              finding: false,
              onFind: () {},
              history: const SizedBox(),
              export: const SizedBox(),
              webUrl: Uri.parse('https://zt.example.com/doc-view-50.html'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.link300));
    await tester.pump();
    expect(copied, 'https://zt.example.com/doc-view-50.html');
    expect(find.text('Link to the document copied'), findsOneWidget);
  });
}
