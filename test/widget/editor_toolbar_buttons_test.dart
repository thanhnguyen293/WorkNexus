import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';
import 'package:work_nexus/core/widgets/rich_text_editor.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('the editor toolbar uses the Lucide set of the chat composer', (
    tester,
  ) async {
    final controller = HtmlEditingController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.dark,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: const [
          ...AppL10n.localizationsDelegates,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: RichTextEditor(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    for (final icon in [
      LucideIcons.undo2300,
      LucideIcons.redo2300,
      LucideIcons.bold300,
      LucideIcons.italic300,
      LucideIcons.underline300,
      LucideIcons.strikethrough300,
      LucideIcons.code300,
      LucideIcons.removeFormatting300,
      LucideIcons.listOrdered300,
      LucideIcons.list300,
      LucideIcons.listChecks300,
      LucideIcons.squareCode300,
      LucideIcons.textQuote300,
      LucideIcons.listIndentIncrease300,
      LucideIcons.listIndentDecrease300,
    ]) {
      expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
    }
    expect(find.byIcon(Icons.format_bold), findsNothing);
  });
}
