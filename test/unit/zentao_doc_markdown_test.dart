import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/render_zentao_doc_markdown.dart';

void main() {
  test('title, fenced code and a GFM table survive the copy', () {
    const doc = ZenTaoDoc(
      id: '50',
      title: 'SocialFi Hub',
      libId: '89',
      html:
          '<h3>Endpoint</h3><pre><code>GET /v1/hub\n  x</code></pre>'
          '<table><thead><tr><th>Name</th><th>Type</th></tr></thead>'
          '<tbody><tr><td>user_id</td><td>string</td></tr></tbody></table>'
          '<p>Use <code>not_found</code></p>',
    );

    final md = zenTaoDocMarkdown(doc);

    expect(md, startsWith('# SocialFi Hub\n\n### Endpoint'));
    expect(md, contains('```\nGET /v1/hub\n  x\n```'));
    expect(md, contains('| Name | Type |'));
    expect(md, contains('| user_id | string |'));
    expect(md, contains('`not_found`'));
  });

  test('an attachment document copies its title alone', () {
    const doc = ZenTaoDoc(id: '115', title: 'Payloads', libId: '247');
    expect(zenTaoDocMarkdown(doc), '# Payloads');
  });
}
