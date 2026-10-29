import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/editor_table_cell.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';
import 'package:work_nexus/core/widgets/rich_text_editor.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  const tableHtml = '''
<table class="table" border="1">
  <thead>
    <tr>
      <th>Task ID</th>
      <th>Name</th>
      <th>From Date</th>
      <th>To Date</th>
      <th>Estimation</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>12787</td>
      <td></td>
      <td>12/10/2026</td>
      <td>12/10/2026</td>
      <td>8</td>
      <td></td>
    </tr>
  </tbody>
</table>
''';

  Widget buildApp(HtmlEditingController controller) {
    return MaterialApp(
      locale: const Locale('en'),
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      localizationsDelegates: const [
        ...AppL10n.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: RichTextEditor(controller: controller)),
    );
  }

  testWidgets('tapping on table cell focuses the cell and keeps text inside', (
    tester,
  ) async {
    final controller = HtmlEditingController(html: tableHtml);
    await tester.pumpWidget(buildApp(controller));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(12));

    // Name cell in row 1 is index 7 (6 header cells + cell 0 is 12787)
    final nameField = textFields.at(7);
    await tester.tap(nameField);
    await tester.pumpAndSettle();

    // Verify cell is focused
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    expect(
      focusedContext?.findAncestorWidgetOfExactType<TableCellWidget>(),
      isNotNull,
    );

    // Enter text into the Name cell
    const taskName = '[Socialfi][Backend][Post] Add block violation';
    await tester.enterText(nameField, taskName);
    await tester.pumpAndSettle();

    // The text should be inside the cell and reflected in generated HTML table
    expect(find.text(taskName), findsOneWidget);
    final html = controller.html;
    expect(html.contains(taskName), isTrue);
    expect(
      html.contains('<td style="border:1px solid #000000;padding:5px;'),
      isTrue,
    );

    // The text MUST NOT leak outside the table into Quill document plain text
    final plainText = controller.quill.document.toPlainText();
    expect(plainText.contains(taskName), isFalse);

    controller.dispose();
  });

  testWidgets('pasting with Ctrl+V into table cell stays inside the cell', (
    tester,
  ) async {
    final controller = HtmlEditingController(html: tableHtml);
    await tester.pumpWidget(buildApp(controller));
    await tester.pumpAndSettle();

    // Mock clipboard content
    const pastedText =
        '[Socialfi][Backend][Post] Add block violation in process';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return {'text': pastedText};
        }
        return null;
      },
    );

    final textFields = find.byType(TextFormField);
    final nameField = textFields.at(7);
    await tester.tap(nameField);
    await tester.pumpAndSettle();

    // Send PasteTextIntent directly
    Actions.invoke(
      tester.element(nameField),
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
    await tester.pumpAndSettle();

    // The pasted text should appear inside the cell
    expect(find.text(pastedText), findsOneWidget);
    final html = controller.html;
    expect(html.contains(pastedText), isTrue);
    expect(
      html.contains('<td style="border:1px solid #000000;padding:5px;'),
      isTrue,
    );

    // The text MUST NOT leak outside the table into Quill document plain text
    final plainText = controller.quill.document.toPlainText();
    expect(plainText.contains(pastedText), isFalse);

    controller.dispose();
  });

  testWidgets(
    'table cells with styled spans and anchor links are cleaned of raw HTML tags',
    (tester) async {
      const styledTableHtml = '''
<table class="table" border="1">
  <thead>
    <tr>
      <th><span style="font-size:13px;font-family:PingFangSC;">Task ID</span></th>
      <th><span style="font-size:13px;font-family:PingFangSC;">Name</span></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><span style="font-size:13px;">13141</span></td>
      <td><a href="https://example.com"><span style="font-size:13px;">[Socialfi] Add violation status</span></a></td>
    </tr>
  </tbody>
</table>
''';
      final controller = HtmlEditingController(html: styledTableHtml);
      await tester.pumpWidget(buildApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Task ID'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('13141'), findsOneWidget);
      expect(find.text('[Socialfi] Add violation status'), findsOneWidget);
      // No raw HTML tags should be rendered in the text fields
      expect(find.textContaining('PingFangSC'), findsNothing);
      expect(find.textContaining('<span'), findsNothing);
      expect(find.textContaining('<a'), findsNothing);

      controller.dispose();
    },
  );

  testWidgets(
    'Tab moves focus to next cell and Shift+Tab moves to previous cell',
    (tester) async {
      final controller = HtmlEditingController(html: tableHtml);
      await tester.pumpWidget(buildApp(controller));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Tap on row 1 cell 0 (index 6, which contains '12787')
      await tester.tap(textFields.at(6));
      await tester.pumpAndSettle();

      // Press Tab to navigate to row 1 cell 1 (index 7, task Name)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Verify row 1 cell 1 (index 7) has focus
      final focused1 = FocusManager.instance.primaryFocus;
      expect(focused1?.debugLabel?.contains('1:1'), isTrue);

      // Press Tab again to navigate to row 1 cell 2 (index 8, From Date)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final focused2 = FocusManager.instance.primaryFocus;
      expect(focused2?.debugLabel?.contains('1:2'), isTrue);

      // Press Shift+Tab to navigate back to row 1 cell 1 (index 7)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      final focused3 = FocusManager.instance.primaryFocus;
      expect(focused3?.debugLabel?.contains('1:1'), isTrue);

      controller.dispose();
    },
  );

  testWidgets(
    'tapping cell places caret without selecting all, typing preserves text and Ctrl+Z undoes',
    (tester) async {
      final controller = HtmlEditingController(html: tableHtml);
      await tester.pumpWidget(buildApp(controller));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Row 1 cell 0 has '12787'
      final cell0 = textFields.at(6);
      await tester.tap(cell0);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      final editableText = tester.widget<EditableText>(
        find.descendant(of: cell0, matching: find.byType(EditableText)),
      );
      // Selection should NOT span the entire text (not auto select-all)
      expect(editableText.controller.selection.isCollapsed, isTrue);

      // Enter additional text via enterText (simulates user input)
      await tester.enterText(cell0, '12787_edited');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('12787_edited'), findsOneWidget);

      // Press Ctrl+Z to undo inside the cell
      final state = tester.state<TableCellWidgetState>(
        find.ancestor(of: cell0, matching: find.byType(TableCellWidget)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('12787'), findsOneWidget);
      expect(state.controller.text, '12787');
      expect(state.undoController.value.canUndo, isFalse);
      controller.dispose();
    },
  );

  testWidgets(
    'strips object replacement characters (\\uFFFC) and control characters from cell input',
    (tester) async {
      final controller = HtmlEditingController(html: tableHtml);
      await tester.pumpWidget(buildApp(controller));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // From Date cell in row 1 is index 8
      final fromDateField = textFields.at(8);
      await tester.tap(fromDateField);
      await tester.pumpAndSettle();

      // Simulate typing or pasting a date with \uFFFC (like in the screenshot)
      await tester.enterText(fromDateField, '20/10/2026\uFFFC');
      await tester.pumpAndSettle();

      expect(find.text('20/10/2026'), findsOneWidget);
      expect(find.text('20/10/2026\uFFFC'), findsNothing);

      final html = controller.html;
      expect(html.contains('\uFFFC'), isFalse);
      expect(html.contains('20/10/2026'), isTrue);
      expect(
        html.contains('<td style="border:1px solid #000000;padding:5px;'),
        isTrue,
      );
      expect(
        html.contains(
          'style="border-collapse:collapse;border:1px solid #000000;"',
        ),
        isTrue,
      );

      controller.dispose();
    },
  );

  testWidgets(
    'Ctrl+A selects all text in cell, and positioning cursor allows deleting and typing characters',
    (tester) async {
      final controller = HtmlEditingController(html: tableHtml);
      await tester.pumpWidget(buildApp(controller));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Row 1 cell 0 has '12787'
      final cell0 = textFields.at(6);
      await tester.tap(cell0);
      await tester.pumpAndSettle();

      final state = tester.state<TableCellWidgetState>(
        find.ancestor(of: cell0, matching: find.byType(TableCellWidget)),
      );

      // Press Ctrl+A
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Verify all text in the cell is selected
      expect(state.controller.selection.baseOffset, 0);
      expect(state.controller.selection.extentOffset, 5);

      // Move cursor to position 2 (after '12')
      state.controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pumpAndSettle();

      // Press backspace to delete '2'
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(state.controller.text, '1787');
      expect(state.controller.selection.baseOffset, 1);

      // Type '9'
      await tester.enterText(cell0, '19787');
      await tester.pumpAndSettle();
      expect(state.controller.text, '19787');

      controller.dispose();
    },
  );

  testWidgets('pressing arrow keys moves cursor without deleting cell content', (
    tester,
  ) async {
    final controller = HtmlEditingController(html: tableHtml);
    await tester.pumpWidget(buildApp(controller));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    // Row 1 cell 2 is 'To Date' / 'From Date' (index 8: '12/10/2026')
    final toDateField = textFields.at(9); // cell 3 in row 1: '12/10/2026'
    await tester.tap(toDateField);
    await tester.pumpAndSettle();

    final state = tester.state<TableCellWidgetState>(
      find.ancestor(of: toDateField, matching: find.byType(TableCellWidget)),
    );

    expect(state.controller.text, '12/10/2026');
    final initialOffset = state.controller.selection.extentOffset;
    expect(initialOffset >= 0, isTrue);

    // Press Left Arrow multiple times
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(state.controller.text, '12/10/2026');
    expect(state.controller.selection.extentOffset, initialOffset - 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(state.controller.text, '12/10/2026');
    expect(state.controller.selection.extentOffset, initialOffset - 2);

    // Press Right Arrow multiple times
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(state.controller.text, '12/10/2026');
    expect(state.controller.selection.extentOffset, initialOffset - 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(state.controller.text, '12/10/2026');
    expect(state.controller.selection.extentOffset, initialOffset);

    // Press Backspace: deletes character before cursor ('/' at position 6 or '1' depending on offset)
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(state.controller.text.length, '12/10/2026'.length - 1);

    controller.dispose();
  });
}
