import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';

void main() {
  test('round-trips ZenTao-style HTML through the editor', () {
    final controller = HtmlEditingController(
      html:
          '<p>[Steps]</p><ol><li>Open <strong>login</strong></li></ol>'
          '<p><img src="https://z.example.com/file-read-1.png" /></p>',
    );
    addTearDown(controller.dispose);

    final html = controller.html;
    expect(html, contains('<strong>login</strong>'));
    expect(html, contains('<ol>'));
    expect(html, contains('src="https://z.example.com/file-read-1.png"'));
  });

  test('an empty editor gives empty HTML', () {
    final controller = HtmlEditingController(html: '<p> </p>');
    addTearDown(controller.dispose);

    expect(controller.html, isEmpty);
  });

  test('keeps an image width from either the attribute or the style', () {
    final controller = HtmlEditingController(
      html:
          '<p><img src="https://z.example.com/a.png" width="320" /></p>'
          '<p><img src="https://z.example.com/b.png" style="width: 480px" /></p>',
    );
    addTearDown(controller.dispose);

    final html = controller.html;
    expect(html, contains('width="320"'));
    expect(html, contains('width="480"'));
  });

  test('a resized image is written back with its new width', () {
    final controller = HtmlEditingController(
      html: '<p><img src="https://z.example.com/a.png" /></p>',
    );
    addTearDown(controller.dispose);
    final quill = controller.quill;
    final at = quill.document.toDelta().toList().indexWhere(
      (op) => op.data is Map,
    );
    expect(at, 0);

    quill.formatText(0, 1, const StyleAttribute('width:240px'));

    expect(controller.html, contains('width="240"'));
  });
}
