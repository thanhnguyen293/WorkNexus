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

  bool route(String url, {bool appTakes = false}) {
    router = LinkRouter();
    app = _Handler((_) => appTakes);
    miniApp = _Handler((u) => findMiniAppForLink(targets, u) != null);
    router
      ..register(LinkStage.app, app)
      ..register(LinkStage.miniApp, miniApp);
    return routeMiniAppWindowLink(router, targets, url, currentAppId: 'trello');
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
}
