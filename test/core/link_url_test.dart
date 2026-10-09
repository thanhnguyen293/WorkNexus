import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/link_url.dart';

void main() {
  test('keeps full http(s) links', () {
    expect(normalizeLinkUrl(' https://a.com/x?y=1 '), 'https://a.com/x?y=1');
    expect(normalizeLinkUrl('http://localhost:8080'), 'http://localhost:8080');
  });

  test('adds https to a bare address', () {
    expect(normalizeLinkUrl('example.com/page'), 'https://example.com/page');
  });

  test('keeps mailto links', () {
    expect(normalizeLinkUrl('mailto:a@b.co'), 'mailto:a@b.co');
  });

  test('rejects what is not a link', () {
    for (final bad in ['', 'hello', 'a b.com', 'ftp://a.com', 'mailto:']) {
      expect(normalizeLinkUrl(bad), isNull, reason: bad);
    }
  });
}
