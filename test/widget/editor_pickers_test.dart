import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/editor_color_button.dart';
import 'package:work_nexus/core/widgets/editor_link_dialog.dart';
import 'package:work_nexus/features/ticket_editor/presentation/widgets/editor_date_input.dart';
import 'package:work_nexus/features/ticket_editor/presentation/widgets/option_multi_select_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  final theme = buildAppTheme(
    variant: AppThemeVariant.dark,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  );
  final colors = theme.extension<AppColors>()!;

  Widget app(Widget child) => MaterialApp(
    theme: theme,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a picked today stays readable on the accent fill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 400,
          child: EditorDateInput(value: today, onChanged: (_) {}),
        ),
      ),
    );
    await tester.tap(find.byType(EditorDateInput));
    await tester.pumpAndSettle();

    final day = tester.widget<Text>(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('${now.day}'),
      ),
    );
    expect(day.style?.color, colors.onAccent);
  });

  testWidgets('the multi-select dialog toggles rows and pops the picks', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<List<String>>(
              context: context,
              builder: (_) => const OptionMultiSelectDialog(
                title: 'Notify',
                options: [
                  FormOption(value: 'a', label: 'Adrian'),
                  FormOption(value: 'b', label: 'Brian'),
                ],
                selected: ['b'],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adrian'));
    await tester.tap(find.text('Brian'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, ['a']);
  });

  testWidgets('the colour drop-down colours the selection and clears it', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.document.insert(0, 'hello');
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.pumpWidget(
      app(
        EditorColorButton(
          controller: controller,
          isBackground: false,
          iconSize: 18,
        ),
      ),
    );

    String? color() =>
        controller.getSelectionStyle().attributes[Attribute.color.key]?.value
            as String?;

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('#e03e2d')));
    await tester.pumpAndSettle();
    expect(color(), '#e03e2d');

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    expect(color(), isNull);
  });

  testWidgets('the link dialog flags a bad link and returns a good one', (
    tester,
  ) async {
    EditorLinkResult? result;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<EditorLinkResult>(
              context: context,
              builder: (_) => const EditorLinkDialog(text: 'docs'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'not a link');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a full link, e.g. https://example.com'), findsOne);

    await tester.enterText(find.byType(TextField).first, 'example.com');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, (text: 'docs', link: 'https://example.com'));
  });

  testWidgets('editing a link offers to remove it', (tester) async {
    EditorLinkResult? result;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<EditorLinkResult>(
              context: context,
              builder: (_) =>
                  const EditorLinkDialog(text: 'docs', link: 'https://a.com'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();
    expect(result, (text: 'docs', link: null));
  });
}
