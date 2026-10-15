import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/is_mini_app_origin.dart';

void main() {
  const isOrigin = IsMiniAppOrigin();
  const app = 'https://zt.example.com/zentao/';

  test('any page on the app\'s own site', () {
    expect(
      isOrigin(app, Uri.parse('https://zt.example.com/bug-view-1.html')),
      isTrue,
    );
    expect(isOrigin(app, Uri.parse('https://ZT.example.com:443/x')), isTrue);
  });

  test('not another site, scheme or port', () {
    expect(isOrigin(app, Uri.parse('https://login.example.com/sso')), isFalse);
    expect(isOrigin(app, Uri.parse('http://zt.example.com/')), isFalse);
    expect(isOrigin(app, Uri.parse('https://zt.example.com:8443/')), isFalse);
  });

  test('not when the page or the app has no address', () {
    expect(isOrigin(app, null), isFalse);
    expect(
      isOrigin('not a url', Uri.parse('https://zt.example.com/')),
      isFalse,
    );
  });
}
