import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/data/mappers/zentao_doc_mapper.dart';

void main() {
  test('libraries map id and name, skipping rows without an id', () {
    final libs = mapZenTaoDocLibs({
      'libs': [
        {'id': 247, 'name': 'Notification'},
        {'id': 12, 'name': ''},
        {'name': 'no id'},
      ],
    });
    expect(libs.map((l) => '${l.id}:${l.name}'), ['247:Notification', '12:12']);
  });

  test('document lists accept a list or an id-keyed map', () {
    final fromList = mapZenTaoDocSummaries({
      'docs': [
        {'id': 115, 'title': 'Payloads', 'acl': 'open'},
      ],
    }, '247');
    final fromMap = mapZenTaoDocSummaries({
      'docs': {
        '116': {'id': 116, 'title': 'Private', 'acl': 'private'},
      },
    }, '247');
    expect(fromList.single.title, 'Payloads');
    expect(fromList.single.libId, '247');
    expect(fromMap.single.acl, 'private');
  });

  test('a text document keeps its HTML and metadata', () {
    final doc = mapZenTaoDoc({
      'id': 111,
      'title': 'Authz API',
      'lib': '247',
      'type': 'text',
      'content': '<div><h1>Authz</h1></div>',
      'version': 21,
      'addedBy': {'account': 'thanh', 'realname': 'Thanh'},
      'editedDate': '2026-10-07T07:30:07Z',
      'files': <Object>[],
    }, baseUrl: 'https://zt.example/zentao');
    expect(doc, isNotNull);
    expect(doc!.hasBody, isTrue);
    expect(doc.isAttachment, isFalse);
    expect(doc.version, 21);
    expect(doc.author?.displayName, 'Thanh');
    expect(doc.author?.account, 'thanh');
    expect(doc.editedDate, DateTime.utc(2026, 10, 7, 7, 30, 7));
  });

  test('an attachment document carries its files', () {
    final doc = mapZenTaoDoc({
      'id': 115,
      'title': 'Payloads',
      'lib': 247,
      'type': 'attachment',
      'content': '',
      'files': [
        {'id': 27696, 'title': 'Payloads.md', 'extension': 'txt', 'size': 5087},
      ],
    }, baseUrl: 'https://zt.example/zentao');
    expect(doc!.isAttachment, isTrue);
    expect(doc.hasBody, isFalse);
    expect(doc.files.single.title, 'Payloads.md');
    expect(
      doc.files.single.url,
      'https://zt.example/zentao/file-download-27696.txt',
    );
  });

  test('editors come from editedList, each once, the last one named', () {
    final doc = mapZenTaoDoc({
      'id': 59,
      'title': 'TBUSD',
      'addedBy': {'account': 'Tompham', 'realname': 'ViPham-VN-go'},
      'editedBy': {'account': 'Tommy', 'realname': 'Saul-VN-GO'},
      'editedList': ',Tompham,Tom,Tommy,tom',
      'views': 42,
    }, baseUrl: '');
    expect(doc!.author?.displayName, 'ViPham-VN-go');
    expect(doc.editors.map((p) => p.account), ['Tompham', 'Tom', 'Tommy']);
    expect(doc.editors.last.displayName, 'Saul-VN-GO');
    expect(doc.views, 42);
  });

  test('escaped titles read back as plain text', () {
    final docs = mapZenTaoDocSummaries({
      'docs': [
        {'id': 7, 'title': 'Post &amp; Restriction'},
      ],
    }, '89');
    final libs = mapZenTaoDocLibs({
      'libs': [
        {'id': 1, 'name': 'A &lt;B&gt;'},
      ],
    });
    expect(docs.single.title, 'Post & Restriction');
    expect(libs.single.name, 'A <B>');
  });

  test('a reply without the document fields is no document', () {
    expect(mapZenTaoDoc({'error': 'denied'}, baseUrl: ''), isNull);
  });
}
