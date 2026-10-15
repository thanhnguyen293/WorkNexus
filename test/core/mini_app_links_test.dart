import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/mini_app_links.dart';

void main() {
  const targets = [
    MiniAppLinkTarget(id: 'root', host: 'example.com'),
    MiniAppLinkTarget(id: 'docs', host: 'docs.example.com'),
  ];

  test('matches the site and its subdomains', () {
    expect(findMiniAppForLink(targets, 'https://example.com/a'), 'root');
    expect(findMiniAppForLink(targets, 'http://www.example.com'), 'root');
  });

  test('prefers the more specific host', () {
    expect(findMiniAppForLink(targets, 'https://docs.example.com/x'), 'docs');
  });

  test('ignores other sites, lookalikes and non-web links', () {
    expect(findMiniAppForLink(targets, 'https://notexample.com'), isNull);
    expect(findMiniAppForLink(targets, 'mailto:a@example.com'), isNull);
    expect(findMiniAppForLink(targets, 'file:///example.com'), isNull);
    expect(findMiniAppForLink(targets, '/relative'), isNull);
  });
}
