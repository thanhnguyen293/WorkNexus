import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/mini_app_links.dart';
import 'package:work_nexus/core/platform/link_router.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/route_mini_app_window_link.dart';

class _Handler implements LinkHandler {
  _Handler(this.takes);

  /// Whether this handler takes [url]; the real mini app one takes the links
  /// of the sites it has an app for.
  final bool Function(String url) takes;
  final seen = <String>[];

  @override
  bool handle(String url) {
    seen.add(url);
    return takes(url);
  }
}

const targets = [
  MiniAppLinkTarget(id: 'trello', host: 'trello.com'),
  MiniAppLinkTarget(id: 'figma', host: 'figma.com'),
];

void main() {
  late LinkRouter router;
  late _Handler app;
  late _Handler miniApp;

  bool route(
    String url, {
    bool appTakes = false,
    double? width,
    double? height,
  }) {
    router = LinkRouter();
    app = _Handler((_) => appTakes);
    miniApp = _Handler((u) => findMiniAppForLink(targets, u) != null);
    router
      ..register(LinkStage.app, app)
      ..register(LinkStage.miniApp, miniApp);
    return routeMiniAppWindowLink(
      router,
      targets,
      url,
      currentAppId: 'trello',
      windowWidth: width,
      windowHeight: height,
    );
  }

  test('the app comes first, then the mini app of the site', () {
    expect(route('https://zentao.io/bug-view-1.html', appTakes: true), isTrue);
    expect(miniApp.seen, isEmpty);
    expect(route('https://www.figma.com/design/x'), isTrue);
    expect(miniApp.seen, ['https://www.figma.com/design/x']);
  });

  test('a link to the app\'s own site is left to its own pop-up', () {
    expect(route('https://trello.com/c/abc'), isFalse);
    expect(miniApp.seen, isEmpty);
  });

  test('a site with no mini app is left to the pop-up', () {
    expect(route('https://example.org'), isFalse);
  });

  group('a sign-in stays a pop-up, whatever app it goes to', () {
    test('one the page sized, for a site that has a mini app', () {
      expect(
        route('https://www.figma.com/design/x', width: 500, height: 650),
        isFalse,
      );
      expect(miniApp.seen, isEmpty);
    });

    test('one whose address says it, for a site that has a mini app', () {
      expect(route('https://www.figma.com/login?next=/files'), isFalse);
      expect(
        route('https://www.figma.com/oauth/authorize?client_id=x'),
        isFalse,
      );
      expect(miniApp.seen, isEmpty);
    });

    test('and no link of the app\'s own is taken for it either', () {
      expect(
        route('https://zentao.io/user-login.html', appTakes: true),
        isFalse,
      );
      expect(app.seen, isEmpty);
    });

    test('a plain link to the same site still goes to its mini app', () {
      expect(route('https://www.figma.com/design/x'), isTrue);
    });
  });
}
