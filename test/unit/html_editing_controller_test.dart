import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/editor_table_embed.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';
import 'package:work_nexus/core/widgets/html_table_parser.dart';

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
      <td><a href="http://zentao/task-12787">[Socialfi][Backend][Feed] Add reply hierarchy ids</a></td>
      <td>12/10/2026</td>
      <td>12/10/2026</td>
      <td>8</td>
      <td></td>
    </tr>
  </tbody>
</table>
''';

  test(
    'preserves exact HTML table when untouched in HtmlEditingController',
    () {
      final controller = HtmlEditingController(html: tableHtml);
      // When unchanged, exact HTML is returned
      expect(controller.html, equals(tableHtml));
      controller.dispose();
    },
  );

  test('editor parses table HTML into table embed in document delta', () {
    final controller = HtmlEditingController(html: tableHtml);
    final delta = controller.quill.document.toDelta().toList();
    final tableOp = delta.firstWhere(
      (op) =>
          op.data is Map &&
          (op.data as Map).containsKey(EditorTableEmbedBuilder.tableType),
    );
    expect(tableOp, isNotNull);
    final rows = parseTableRows(
      (tableOp.data as Map)[EditorTableEmbedBuilder.tableType],
    );
    expect(rows.first, contains('Task ID'));
    expect(rows.first, contains('Name'));
    expect(rows[1].first, equals('12787'));
    controller.dispose();
  });

  test('restores edited or reconstructed table to valid HTML table', () {
    final controller = HtmlEditingController(html: tableHtml);
    controller.quill.document.insert(0, 'Note:\n');
    final result = controller.html;

    expect(result.contains('<table'), isTrue);
    expect(result.contains('>Task ID</th>'), isTrue);
    expect(result.contains('>12787</td>'), isTrue);
    expect(result.contains('Note:'), isTrue);
    controller.dispose();
  });

  test(
    'converts typed markdown table with multiple rows into a single HTML table',
    () {
      final controller = HtmlEditingController();
      const typedTable =
          '| Header 1 | Header 2 |\n'
          '| --- | --- |\n'
          '| Value 1 | Value 2 |\n'
          '| Value 3 | Value 4 |\n';
      controller.quill.document.insert(0, typedTable);
      final result = controller.html;

      expect(result.contains('<table'), isTrue);
      // Should be exactly ONE table, not multiple tables
      expect(result.indexOf('<table'), equals(result.lastIndexOf('<table')));
      expect(result.contains('>Header 1</th>'), isTrue);
      expect(result.contains('>Header 2</th>'), isTrue);
      expect(result.contains('>Value 1</td>'), isTrue);
      expect(result.contains('>Value 2</td>'), isTrue);
      expect(result.contains('>Value 3</td>'), isTrue);
      expect(result.contains('>Value 4</td>'), isTrue);
      // Separator row should be stripped
      expect(result.contains('---'), isFalse);
      controller.dispose();
    },
  );

  test(
    'preserves text before and after a table without corrupting table structure',
    () {
      final controller = HtmlEditingController();
      const content =
          'Before table text\n'
          '| Col A | Col B |\n'
          '| Val A | Val B |\n'
          'After table text\n';
      controller.quill.document.insert(0, content);
      final result = controller.html;

      expect(result.contains('Before table text'), isTrue);
      expect(result.contains('<table'), isTrue);
      expect(result.contains('>Col A</th>'), isTrue);
      expect(result.contains('>Val A</td>'), isTrue);
      expect(result.contains('After table text'), isTrue);
      controller.dispose();
    },
  );

  test('serializes inserted table BlockEmbed into valid HTML table', () {
    final controller = HtmlEditingController();
    controller.quill.replaceText(
      0,
      0,
      const BlockEmbed(
        EditorTableEmbedBuilder.tableType,
        '{"rows":[["Col 1","Col 2"],["Val 1","Val 2"]]}',
      ),
      null,
    );
    final html = controller.html;
    expect(html, contains('<table'));
    expect(html, contains('>Col 1</th>'));
    expect(html, contains('>Col 2</th>'));
    expect(html, contains('>Val 1</td>'));
    expect(html, contains('>Val 2</td>'));
    controller.dispose();
  });

  test('strips \\uFFFC and control characters from untouched initial HTML', () {
    const raw = '<p>Task 20/10/2026\uFFFC with object char</p>';
    final controller = HtmlEditingController(html: raw);
    expect(controller.html, equals('<p>Task 20/10/2026 with object char</p>'));
    controller.dispose();
  });

  test(
    'editing a table in one controller does not affect untouched table in another controller',
    () {
      final controller1 = HtmlEditingController(html: tableHtml);
      final controller2 = HtmlEditingController(html: tableHtml);

      // Edit table in controller1
      final delta1 = controller1.quill.document.toDelta().toList();
      final tableOp = delta1.firstWhere(
        (op) =>
            op.data is Map &&
            (op.data as Map).containsKey(EditorTableEmbedBuilder.tableType),
      );
      final tableData =
          (tableOp.data as Map)[EditorTableEmbedBuilder.tableType];
      final tableId = parseTableId(tableData)!;
      controller1.tableStore.set(tableId, [
        ['Modified Header'],
        ['Modified Value'],
      ]);

      // controller1 has changes, so it serializes modified HTML
      expect(controller1.tableStore.hasAnyChanges, isTrue);
      expect(controller1.html, contains('Modified Header'));

      // controller2 has NOT been edited, so it returns the exact initial HTML
      expect(controller2.tableStore.hasAnyChanges, isFalse);
      expect(controller2.html, equals(tableHtml));

      controller1.dispose();
      controller2.dispose();
    },
  );

  test('preserves single pipe row as text without converting to table', () {
    final controller = HtmlEditingController();
    const content = 'Bug report:\n| expected | actual |\nFixed soon.\n';
    controller.quill.document.insert(0, content);
    final result = controller.html;

    expect(result.contains('<table'), isFalse);
    expect(result.contains('| expected | actual |'), isTrue);
    expect(result.contains('Bug report:'), isTrue);
    expect(result.contains('Fixed soon.'), isTrue);
    controller.dispose();
  });

  test('preserves compound emoji with ZWJ in untouched HTML', () {
    const raw = '<p>Family emoji: 👨‍👩‍👧‍👦 untouched</p>';
    final controller = HtmlEditingController(html: raw);
    expect(controller.html, equals(raw));
    controller.dispose();
  });

  test('does not double escape HTML entities in table cells', () {
    const rawHtml =
        '<p>| <strong>strong</strong> | a &amp; b |<br>'
        '| --- | --- |<br>'
        '| <em>italic</em> | c &lt; d |</p>';
    final result = restoreTables(rawHtml);

    expect(result.contains('&lt;strong&gt;'), isFalse);
    expect(result.contains('&amp;amp;'), isFalse);
    expect(result.contains('<strong>strong</strong>'), isTrue);
    expect(result.contains('a &amp; b'), isTrue);
  });

  test('preserves order of text between tables without shifting', () {
    final controller = HtmlEditingController();
    const mixed =
        '| H1 | H2 |\n'
        '| --- | --- |\n'
        '| V1 | V2 |\n'
        'Middle note between tables\n'
        '| H3 | H4 |\n'
        '| --- | --- |\n'
        '| V3 | V4 |\n';
    controller.quill.document.insert(0, mixed);
    final result = controller.html;

    final firstTableIdx = result.indexOf('V1</td>');
    final noteIdx = result.indexOf('Middle note between tables');
    final secondTableIdx = result.indexOf('V3</td>');

    expect(firstTableIdx, isNonNegative);
    expect(noteIdx, isNonNegative);
    expect(secondTableIdx, isNonNegative);
    expect(firstTableIdx < noteIdx, isTrue);
    expect(noteIdx < secondTableIdx, isTrue);
    controller.dispose();
  });
}
