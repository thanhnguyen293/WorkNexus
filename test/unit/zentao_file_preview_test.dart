import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/tools/zentao/presentation/util/zentao_file_preview.dart';

TicketAttachment _file(String title, [String? ext]) =>
    TicketAttachment(id: '1', title: title, url: 'u', extension: ext);

void main() {
  test('a .md upload ZenTao files as txt still previews as Markdown', () {
    expect(
      zenTaoFilePreviewOf(_file('# Payloads.md', 'txt')),
      ZenTaoFilePreview.markdown,
    );
  });

  test('text, images and the rest', () {
    expect(zenTaoFilePreviewOf(_file('api.json')), ZenTaoFilePreview.text);
    expect(zenTaoFilePreviewOf(_file('shot.PNG')), ZenTaoFilePreview.image);
    expect(zenTaoFilePreviewOf(_file('spec.pdf')), ZenTaoFilePreview.none);
  });

  test('falls back to the reported extension when the name has none', () {
    expect(zenTaoFilePreviewOf(_file('README', 'txt')), ZenTaoFilePreview.text);
  });
}
