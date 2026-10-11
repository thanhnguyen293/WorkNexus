import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_image_context_menu.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> open(WidgetTester tester, {VoidCallback? onCopy}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChatImageContextMenu(
              context,
              at: const Offset(100, 100),
              onCopy: onCopy,
              onSave: () {},
              onOpenExternally: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('right-click offers copy, and copying runs it', (tester) async {
    var copied = 0;
    await open(tester, onCopy: () => copied++);
    expect(find.text('Copy image'), findsOneWidget);

    await tester.tap(find.text('Copy image'));
    await tester.pumpAndSettle();
    expect(copied, 1);
  });

  testWidgets('no copy until the original has loaded', (tester) async {
    await open(tester);
    expect(find.text('Copy image'), findsNothing);
    expect(find.byType(InkWell), findsWidgets);
  });
}
