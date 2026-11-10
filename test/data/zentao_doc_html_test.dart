import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/data/mappers/zentao_doc_html.dart';

void main() {
  test('drops the white background pinned on code blocks', () {
    final out = tidyZenTaoDocHtml(
      '<pre class="shiki" style="background-color:#FFFFFF;color:#000000;">'
      '<code>GET /a</code></pre>',
    );
    expect(out, isNot(contains('background-color')));
    expect(out, contains('<code>GET /a</code>'));
  });

  test('drops an empty table header row, keeping the body', () {
    final out = tidyZenTaoDocHtml(
      '<table><thead><tr><th></th><th></th></tr></thead>'
      '<tbody><tr><td><strong>Method</strong></td><td>GET</td></tr></tbody>'
      '</table>',
    );
    expect(out, isNot(contains('<thead>')));
    expect(out, contains('<td>GET</td>'));
  });

  test('keeps a real header row', () {
    final out = tidyZenTaoDocHtml(
      '<table><thead><tr><th>Name</th></tr></thead><tbody></tbody></table>',
    );
    expect(out, contains('<th>Name</th>'));
  });

  test('drops blank paragraphs but keeps one holding an image', () {
    final out = tidyZenTaoDocHtml(
      '<div><p></p></div><p> </p><p><img src="a.png"></p><p>Text</p>',
    );
    expect(RegExp('<p>').allMatches(out).length, 2);
    expect(out, contains('a.png'));
  });
}
