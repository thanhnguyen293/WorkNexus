import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/link_router.dart';
import 'package:work_nexus/core/platform/open_external.dart';

class _Handler implements LinkHandler {
  _Handler(this.name, this.calls, {required this.opens});

  final String name;
  final List<String> calls;
  final bool opens;

  @override
  bool handle(String url) {
    calls.add(name);
    return opens;
  }
}

void main() {
  final calls = <String>[];
  late LinkRouter router;
  setUp(() {
    calls.clear();
    router = LinkRouter();
  });

  void register({required bool appOpens, required bool miniOpens}) {
    router
      ..register(LinkStage.app, _Handler('app', calls, opens: appOpens))
      ..register(LinkStage.miniApp, _Handler('mini', calls, opens: miniOpens));
  }

  test('the app shows the link itself before a mini app or the browser', () {
    register(appOpens: true, miniOpens: true);
    expect(router.route('https://zt.example/bug-view-1.html'), isTrue);
    expect(calls, ['app']);
  });

  test('a mini app comes next when the app has no view of the link', () {
    register(appOpens: false, miniOpens: true);
    expect(router.route('https://example.com'), isTrue);
    expect(calls, ['app', 'mini']);
  });

  test('false means the browser: nobody opened it', () {
    register(appOpens: false, miniOpens: false);
    expect(router.route('https://example.com'), isFalse);
    expect(calls, ['app', 'mini']);
  });

  test('skipped stages are not asked', () {
    register(appOpens: true, miniOpens: true);
    expect(
      router.route('https://zt.example/bug-view-1.html', skip: {LinkStage.app}),
      isTrue,
    );
    expect(calls, ['mini']);
  });

  test('a stale unregister does not remove its replacement', () {
    final first = _Handler('first', calls, opens: true);
    final second = _Handler('second', calls, opens: true);
    router
      ..register(LinkStage.app, first)
      ..register(LinkStage.app, second)
      ..unregister(LinkStage.app, first);
    router.route('https://example.com');
    expect(calls, ['second']);
  });

  test('openLinkExternally hands only web links to the router', () async {
    register(appOpens: true, miniOpens: true);
    await openLinkExternally('/relative/path', router: router);
    expect(calls, isEmpty);
    await openLinkExternally('https://a.io', router: router);
    expect(calls, ['app']);
    calls.clear();
    await openLinkExternally('https://a.io', inApp: false, router: router);
    expect(calls, ['mini']);
  });
}
