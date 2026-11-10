import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:work_nexus/tools/zentao/presentation/util/zentao_doc_prepare.dart';

void main() {
  test('headings h1–h4 are anchored and listed in order', () {
    final p = prepareZenTaoDocHtml(
      '<h1>API</h1><p>x</p><h3><strong>Auth</strong></h3><h5>skip</h5><h2> </h2>',
    );
    expect(p.headings.map((h) => (h.level, h.text, h.index)), [
      (1, 'API', 0),
      (3, 'Auth', 1),
    ]);
    expect(p.html, contains('<h1><zt-anchor data-heading="0"></zt-anchor>API'));
  });

  test('matches are marked case-insensitively, in reading order', () {
    final p = prepareZenTaoDocHtml(
      '<p>Token <b>token</b></p><pre><code>TOKEN=1</code></pre>',
      query: 'token',
    );
    expect(p.matchCount, 3);
    final marks = parseFragment(p.html).querySelectorAll('mark');
    expect(marks.map((m) => (m.text, m.attributes['data-find'])), [
      ('Token', '0'),
      ('token', '1'),
      ('TOKEN', '2'),
    ]);
  });

  test('the query is literal text, not a pattern', () {
    final p = prepareZenTaoDocHtml('<p>a.b axb</p>', query: 'a.b');
    expect(p.matchCount, 1);
  });

  test('no query leaves the text alone', () {
    final p = prepareZenTaoDocHtml('<p>Token</p>', query: '  ');
    expect(p.matchCount, 0);
    expect(p.html, isNot(contains('<mark')));
  });

  test('marks are found back with their ranges in a code block', () {
    final p = prepareZenTaoDocHtml(
      '<pre><code>GET /a\nGET /b</code></pre>',
      query: 'get',
    );
    final pre = parseFragment(p.html).querySelector('pre')!;
    expect(zenTaoFindRanges(pre), [
      (index: 0, start: 0, end: 3),
      (index: 1, start: 7, end: 10),
    ]);
    expect(pre.text, 'GET /a\nGET /b');
  });
}
