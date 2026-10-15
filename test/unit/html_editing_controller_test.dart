import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';

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

  test(
    'editor displays table rows with line breaks rather than fused text',
    () {
      final controller = HtmlEditingController(html: tableHtml);
      final plainText = controller.quill.document.toPlainText();
      // Cells should not be fused together like Task IDNameFrom Date...
      expect(plainText.contains('Task IDNameFrom Date'), isFalse);
      expect(plainText.contains('Task ID'), isTrue);
      expect(plainText.contains('Name'), isTrue);
      expect(plainText.contains('12787'), isTrue);
      expect(
        plainText.contains('[Socialfi][Backend][Feed] Add reply hierarchy ids'),
        isTrue,
      );
      controller.dispose();
    },
  );

  test('restores edited or reconstructed table to valid HTML table', () {
    final controller = HtmlEditingController(html: tableHtml);
    controller.quill.document.insert(0, 'Note:\n');
    final result = controller.html;

    expect(result.contains('<table'), isTrue);
    expect(result.contains('<th>Task ID</th>'), isTrue);
    expect(result.contains('<td>12787</td>'), isTrue);
    expect(result.contains('Note:'), isTrue);
    controller.dispose();
  });
}
